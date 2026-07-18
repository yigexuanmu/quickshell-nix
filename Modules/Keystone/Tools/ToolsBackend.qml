import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services

Item {
    id: backendRoot
    
    function pickColor() { colorPickerProcess.running = false; colorPickerProcess.running = true }
    function takeScreenshot() { screenshotProcess.running = false; screenshotProcess.running = true }

    function startRecord(mode) {
        RecordingService.start(mode, {
            audio: "none",
            fps: 60
        })
    }

    function stopRecord() {
        RecordingService.stop()
    }

    function startAudio(source) {
        return AudioRecordingService.start(source)
    }

    function stopAudio() {
        return AudioRecordingService.stop()
    }

    // 简单工具依然保持内联
    Process { id: colorPickerProcess; command: ["bash", "-c", "nohup bash -c 'sleep 0.3; hyprpicker -a' >/dev/null 2>&1 &"] }
    Process { id: screenshotProcess; command: ["bash", "-c", "nohup bash -c 'sleep 0.3; grim -g \"$(slurp)\" - | wl-copy' >/dev/null 2>&1 &"] }
}
