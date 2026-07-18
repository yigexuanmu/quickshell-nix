pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Clavis 自己的会话始终优先于外部 niri Cast。
    readonly property bool ownSessionPresent: RecordingService.isActive
    readonly property bool ownRecordingActive: RecordingService.isRecording
    readonly property bool externalCapturePresent: ScreencastService.anyCastPresent
    readonly property bool externalCaptureActive: ScreencastService.anyCastActive
    readonly property bool capturePresent: ownSessionPresent || externalCapturePresent
    readonly property bool captureActive: ownRecordingActive || externalCaptureActive
    readonly property string source: ownSessionPresent
        ? "clavis"
        : (externalCapturePresent ? "external" : "none")
    readonly property string state: ownSessionPresent
        ? RecordingService.state
        : (externalCaptureActive ? "capturing" : "idle")
    readonly property var ownStatusTexts: ({
        "selecting": "正在选择录制区域",
        "starting": "正在启动录制",
        "recording": "正在录制",
        "finalizing": "正在处理录制文件"
    })
    readonly property string statusText: ownSessionPresent
        ? (ownStatusTexts[RecordingService.state] || "")
        : ScreencastService.statusText
    readonly property bool canStop: RecordingService.isRecording
        || RecordingService.isFinalizing
}
