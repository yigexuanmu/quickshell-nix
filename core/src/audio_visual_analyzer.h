#pragma once

#include <QtGlobal>

#include <deque>
#include <vector>

enum class AudioVisualSource {
    Microphone,
    System,
};

class AudioVisualAnalyzer {
public:
    explicit AudioVisualAnalyzer(
        AudioVisualSource source = AudioVisualSource::Microphone);

    void reset(AudioVisualSource source);
    void addSample(double rms, double peak, bool available = true);
    double commit(qint64 timestampMs);
    double systemDisplayGain() const;

private:
    struct TimedEnergy {
        qint64 timestampMs = 0;
        double value = 0.0;
    };

    AudioVisualSource m_source = AudioVisualSource::Microphone;
    std::vector<double> m_windowRms;
    std::vector<double> m_windowPeaks;
    std::deque<TimedEnergy> m_systemHistory;
    double m_microphoneLevel = 0.0;
    double m_systemDisplayGain = 1.0;
    double m_systemLowReference = 0.0;
    qint64 m_lastCommitAt = 0;

    double summarizeWindow();
    double adaptSystemEnergy(double value, qint64 timestampMs,
                             qint64 elapsedMs);
};
