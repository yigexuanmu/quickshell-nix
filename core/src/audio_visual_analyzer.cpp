#include "audio_visual_analyzer.h"

#include <algorithm>
#include <cmath>

namespace {

struct AnalysisProfile {
    double rmsWeight = 0.0;
    double p90Weight = 0.0;
    double peakWeight = 0.0;
    double noiseFloorDb = 0.0;
    double ceilingDb = 0.0;
    double gamma = 1.0;
};

constexpr AnalysisProfile kSystemProfile{
    0.55, 0.30, 0.15, -55.0, -8.0, 1.20,
};
constexpr AnalysisProfile kMicrophoneProfile{
    0.70, 0.20, 0.10, -50.0, -10.0, 0.95,
};
constexpr qint64 kAdaptiveWindowMs = 3000;
constexpr qint64 kVisualIntervalMs = 160;

double clamp01(double value)
{
    return std::clamp(value, 0.0, 1.0);
}

double percentile(std::vector<double> values, double quantile)
{
    if (values.empty())
        return 0.0;

    std::sort(values.begin(), values.end());
    const double position =
        static_cast<double>(values.size() - 1) * quantile;
    const auto lower = static_cast<std::size_t>(std::floor(position));
    const auto upper = static_cast<std::size_t>(std::ceil(position));
    if (lower == upper)
        return values[lower];
    const double fraction = position - static_cast<double>(lower);
    return values[lower] * (1.0 - fraction) + values[upper] * fraction;
}

double mapEnergy(double value, const AnalysisProfile &profile)
{
    const double linear = std::max(0.000001, value);
    const double decibels = 20.0 * std::log10(linear);
    if (decibels <= profile.noiseFloorDb)
        return 0.0;
    const double normalized = clamp01(
        (decibels - profile.noiseFloorDb)
        / (profile.ceilingDb - profile.noiseFloorDb));
    return std::pow(normalized, profile.gamma);
}

double softCompressPeak(double value)
{
    const double mapped = clamp01(value);
    constexpr double knee = 0.72;
    if (mapped <= knee)
        return mapped;
    const double progress = (mapped - knee) / (1.0 - knee);
    const double curve =
        (1.0 - std::exp(-2.2 * progress)) / (1.0 - std::exp(-2.2));
    return knee + (0.92 - knee) * curve;
}

double smoothedValue(double current, double target, qint64 elapsedMs,
                     double durationMs)
{
    const double alpha =
        1.0 - std::exp(-static_cast<double>(std::max<qint64>(1, elapsedMs))
                       / std::max(1.0, durationMs));
    return current + (target - current) * alpha;
}

} // namespace

AudioVisualAnalyzer::AudioVisualAnalyzer(AudioVisualSource source)
    : m_source(source)
{
}

void AudioVisualAnalyzer::reset(AudioVisualSource source)
{
    m_source = source;
    m_windowRms.clear();
    m_windowPeaks.clear();
    m_systemHistory.clear();
    m_microphoneLevel = 0.0;
    m_systemDisplayGain = 1.0;
    m_systemLowReference = 0.0;
    m_lastCommitAt = 0;
}

void AudioVisualAnalyzer::addSample(double rms, double peak, bool available)
{
    m_windowRms.push_back(available ? clamp01(rms) : 0.0);
    m_windowPeaks.push_back(available ? clamp01(peak) : 0.0);
    constexpr std::size_t maximumWindowSamples = 16;
    if (m_windowRms.size() > maximumWindowSamples)
        m_windowRms.erase(m_windowRms.begin());
    if (m_windowPeaks.size() > maximumWindowSamples)
        m_windowPeaks.erase(m_windowPeaks.begin());
}

double AudioVisualAnalyzer::commit(qint64 timestampMs)
{
    const double summarized = summarizeWindow();
    const qint64 elapsed = m_lastCommitAt > 0
        ? std::clamp(timestampMs - m_lastCommitAt,
                     static_cast<qint64>(1), static_cast<qint64>(500))
        : kVisualIntervalMs;
    m_lastCommitAt = timestampMs;

    if (m_source == AudioVisualSource::System)
        return adaptSystemEnergy(summarized, timestampMs, elapsed);

    const double alpha = summarized > m_microphoneLevel ? 0.48 : 0.22;
    m_microphoneLevel += (summarized - m_microphoneLevel) * alpha;
    return clamp01(m_microphoneLevel);
}

double AudioVisualAnalyzer::systemDisplayGain() const
{
    return m_systemDisplayGain;
}

double AudioVisualAnalyzer::summarizeWindow()
{
    if (m_windowRms.empty()) {
        m_windowPeaks.clear();
        return 0.0;
    }

    double squareSum = 0.0;
    for (const double value : m_windowRms)
        squareSum += value * value;
    const double windowRms =
        std::sqrt(squareSum / static_cast<double>(m_windowRms.size()));
    const double windowP90 = percentile(m_windowRms, 0.90);
    const double windowPeak = m_windowPeaks.empty()
        ? 0.0
        : *std::max_element(m_windowPeaks.begin(), m_windowPeaks.end());
    const AnalysisProfile &profile =
        m_source == AudioVisualSource::System
        ? kSystemProfile
        : kMicrophoneProfile;

    const double mappedRms = mapEnergy(windowRms, profile);
    const double mappedP90 = mapEnergy(windowP90, profile);
    const double mappedPeak =
        softCompressPeak(mapEnergy(windowPeak, profile));
    m_windowRms.clear();
    m_windowPeaks.clear();
    return clamp01(mappedRms * profile.rmsWeight
                   + mappedP90 * profile.p90Weight
                   + mappedPeak * profile.peakWeight);
}

double AudioVisualAnalyzer::adaptSystemEnergy(double value,
                                              qint64 timestampMs,
                                              qint64 elapsedMs)
{
    m_systemHistory.push_back({timestampMs, value});
    while (!m_systemHistory.empty()
           && timestampMs - m_systemHistory.front().timestampMs
               > kAdaptiveWindowMs) {
        m_systemHistory.pop_front();
    }

    if (m_systemHistory.size() < 8)
        return value;

    std::vector<double> energies;
    energies.reserve(m_systemHistory.size());
    for (const TimedEnergy &sample : m_systemHistory)
        energies.push_back(sample.value);
    const double low = percentile(energies, 0.20);
    const double high = percentile(energies, 0.90);

    if (value <= 0.035 || high <= 0.08) {
        m_systemDisplayGain = smoothedValue(
            m_systemDisplayGain, 1.0, elapsedMs, 2000.0);
        m_systemLowReference = smoothedValue(
            m_systemLowReference, 0.0, elapsedMs, 2000.0);
        return clamp01(value * m_systemDisplayGain);
    }

    const double dynamicRange = std::max(0.001, high - low);
    const double targetGain =
        std::clamp(0.48 / std::max(0.24, dynamicRange), 0.75, 2.0);
    const double gainDuration =
        targetGain < m_systemDisplayGain ? 250.0 : 1200.0;
    const double lowDuration =
        low > m_systemLowReference ? 250.0 : 1200.0;
    m_systemDisplayGain = smoothedValue(
        m_systemDisplayGain, targetGain, elapsedMs, gainDuration);
    m_systemLowReference = smoothedValue(
        m_systemLowReference, low, elapsedMs, lowDuration);

    const double displayFloor =
        std::clamp(m_systemLowReference * 0.5, 0.06, 0.32);
    const double adapted = displayFloor
        + (value - m_systemLowReference) * m_systemDisplayGain;
    return clamp01(adapted * 0.85 + value * 0.15);
}
