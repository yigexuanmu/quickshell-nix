#include "audio_visual_analyzer.h"

#include <QTest>

class AudioVisualAnalyzerTest : public QObject {
    Q_OBJECT

private slots:
    void appliesMicrophoneNoiseGate();
    void preservesSystemTransients();
    void boundsAndRecoversSystemGain();
};

void AudioVisualAnalyzerTest::appliesMicrophoneNoiseGate()
{
    AudioVisualAnalyzer analyzer(AudioVisualSource::Microphone);
    for (int index = 0; index < 5; ++index)
        analyzer.addSample(0.001, 0.002);
    QCOMPARE(analyzer.commit(160), 0.0);

    for (int index = 0; index < 5; ++index)
        analyzer.addSample(0.03, 0.10);
    QVERIFY(analyzer.commit(320) > 0.2);
}

void AudioVisualAnalyzerTest::preservesSystemTransients()
{
    AudioVisualAnalyzer steady(AudioVisualSource::System);
    for (int index = 0; index < 5; ++index)
        steady.addSample(0.04, 0.08);
    const double steadyLevel = steady.commit(160);

    AudioVisualAnalyzer transient(AudioVisualSource::System);
    for (int index = 0; index < 4; ++index)
        transient.addSample(0.04, 0.08);
    transient.addSample(0.15, 0.80);
    const double transientLevel = transient.commit(160);
    QVERIFY(transientLevel > steadyLevel + 0.08);
}

void AudioVisualAnalyzerTest::boundsAndRecoversSystemGain()
{
    AudioVisualAnalyzer analyzer(AudioVisualSource::System);
    qint64 timestamp = 0;
    for (int window = 0; window < 16; ++window) {
        for (int sample = 0; sample < 5; ++sample) {
            const double offset = (window % 3) * 0.004;
            analyzer.addSample(0.07 + offset, 0.18 + offset);
        }
        timestamp += 160;
        analyzer.commit(timestamp);
    }
    const double adaptedGain = analyzer.systemDisplayGain();
    QVERIFY(adaptedGain > 1.0);
    QVERIFY(adaptedGain <= 2.0);

    for (int window = 0; window < 8; ++window) {
        for (int sample = 0; sample < 5; ++sample)
            analyzer.addSample(0.0, 0.0);
        timestamp += 160;
        analyzer.commit(timestamp);
    }
    QVERIFY(analyzer.systemDisplayGain() < adaptedGain);
    QVERIFY(analyzer.systemDisplayGain() >= 0.75);
}

QTEST_MAIN(AudioVisualAnalyzerTest)
#include "audio_visual_analyzer_test.moc"
