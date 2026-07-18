import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Clavis.Audio 1.0
import qs.Common

Item {
    id: root

    required property bool sessionActive
    required property bool recording
    required property bool stopping
    required property string sourceNodeName
    required property bool captureSink
    required property double elapsedMs

    property real waveformProgress: 0
    property real controlsProgress: 0
    property real exitCompression: 0
    readonly property real contentBlur: Math.max(
        1 - waveformProgress, exitCompression) * 0.55

    signal stopRequested()
    signal collapseRequested()
    signal exitFinished()

    function formatElapsed(milliseconds) {
        const totalSeconds = Math.max(0, Math.floor(milliseconds / 1000));
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        const pad = value => value < 10 ? "0" + value : String(value);
        return hours > 0
            ? pad(hours) + ":" + pad(minutes) + ":" + pad(seconds)
            : pad(minutes) + ":" + pad(seconds);
    }

    function beginEntry() {
        exitAnimation.stop();
        collapseTimer.stop();
        exitFinishTimer.stop();
        root.waveformProgress = 0;
        root.controlsProgress = 0;
        root.exitCompression = 0;
        entryAnimation.restart();
    }

    function beginExit() {
        entryAnimation.stop();
        root.exitCompression = 0;
        collapseTimer.restart();
        exitFinishTimer.restart();
        exitAnimation.restart();
    }

    AudioLevelProvider {
        id: levelProvider

        active: root.recording && root.sourceNodeName !== ""
        sourceNodeName: root.sourceNodeName
        captureSink: root.captureSink

        onErrorStringChanged: {
            if (errorString !== "")
                console.warn("[AudioLevelProvider]", errorString);
        }
    }

    Item {
        id: contentLayer

        anchors.fill: parent
        opacity: Math.max(root.waveformProgress, root.controlsProgress)
        transform: Scale {
            origin.x: contentLayer.width / 2
            origin.y: contentLayer.height / 2
            xScale: 0.92 + root.waveformProgress * 0.08
                - root.exitCompression * 0.06
            yScale: 1
        }
        layer.enabled: root.contentBlur > 0.001
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 16
            blur: root.contentBlur
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 10
            spacing: 12

            AudioWaveform {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                active: root.sessionActive
                acceptSamples: root.recording
                sourceAvailable: levelProvider.available
                amplitude: levelProvider.normalizedAmplitude
                sampleTimestampMs: levelProvider.timestampMs
                opacity: root.waveformProgress
            }

            Text {
                Layout.preferredWidth: 76
                Layout.alignment: Qt.AlignVCenter
                text: root.formatElapsed(root.elapsedMs)
                horizontalAlignment: Text.AlignRight
                color: Appearance.colors.colError
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                opacity: root.controlsProgress
            }

            AudioStopButton {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                Layout.alignment: Qt.AlignVCenter
                stopping: root.stopping
                canStop: root.recording
                opacity: root.controlsProgress
                onStopRequested: root.stopRequested()
            }
        }
    }

    ParallelAnimation {
        id: entryAnimation

        SequentialAnimation {
            PauseAnimation { duration: KeystoneMotion.audioContentDelay }
            NumberAnimation {
                target: root
                property: "waveformProgress"
                to: 1
                duration: KeystoneMotion.audioContentEnterDuration
                easing.type: Appearance.animation.expressiveSlowEffects.type
                easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: KeystoneMotion.audioControlsDelay }
            NumberAnimation {
                target: root
                property: "controlsProgress"
                to: 1
                duration: KeystoneMotion.audioControlsEnterDuration
                easing.type: Appearance.animation.expressiveSlowEffects.type
                easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
            }
        }
    }

    ParallelAnimation {
        id: exitAnimation

        NumberAnimation {
            target: root
            property: "waveformProgress"
            to: 0
            duration: KeystoneMotion.audioContentExitDuration
            easing.type: Appearance.animation.emphasizedAccel.type
            easing.bezierCurve: Appearance.animation.emphasizedAccel.bezierCurve
        }
        NumberAnimation {
            target: root
            property: "controlsProgress"
            to: 0
            duration: KeystoneMotion.audioContentExitDuration
            easing.type: Appearance.animation.emphasizedAccel.type
            easing.bezierCurve: Appearance.animation.emphasizedAccel.bezierCurve
        }
        NumberAnimation {
            target: root
            property: "exitCompression"
            to: 1
            duration: KeystoneMotion.audioContentExitDuration
            easing.type: Appearance.animation.emphasizedAccel.type
            easing.bezierCurve: Appearance.animation.emphasizedAccel.bezierCurve
        }
    }

    Timer {
        id: collapseTimer

        interval: KeystoneMotion.audioCollapseDelay
        onTriggered: root.collapseRequested()
    }

    Timer {
        id: exitFinishTimer

        interval: KeystoneMotion.audioExitDuration
        onTriggered: root.exitFinished()
    }
}
