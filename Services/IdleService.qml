pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    // Policy defaults intentionally avoid automatic suspend and brightness changes.
    // Every stage remains independently configurable through configureStage().
    property bool policyEnabled: true
    property bool dimEnabled: false
    property real dimTimeout: 300
    property bool dimRespectInhibitors: true
    property real dimFraction: 0.35

    property bool lockEnabled: true
    property real lockTimeout: 600
    property bool lockRespectInhibitors: true

    property bool displayOffEnabled: true
    property real displayOffTimeout: 900
    property bool displayOffRespectInhibitors: true

    property bool suspendEnabled: false
    property real suspendTimeout: 1800
    property bool suspendRespectInhibitors: true

    property alias inhibited: persistentState.inhibited
    property bool dimmed: false
    property bool displaysOff: false
    readonly property bool busy: lockPending || displayPowerProcess.running || suspendProcess.running
    property string lastError: ""

    readonly property var stages: [
        {
            "name": "dim",
            "enabled": dimEnabled,
            "timeout": dimTimeout,
            "respectInhibitors": dimRespectInhibitors,
            "active": dimMonitor.isIdle
        },
        {
            "name": "lock",
            "enabled": lockEnabled,
            "timeout": lockTimeout,
            "respectInhibitors": lockRespectInhibitors,
            "active": lockMonitor.isIdle
        },
        {
            "name": "displayOff",
            "enabled": displayOffEnabled,
            "timeout": displayOffTimeout,
            "respectInhibitors": displayOffRespectInhibitors,
            "active": displayOffMonitor.isIdle
        },
        {
            "name": "suspend",
            "enabled": suspendEnabled,
            "timeout": suspendTimeout,
            "respectInhibitors": suspendRespectInhibitors,
            "active": suspendMonitor.isIdle
        }
    ]

    property bool lockPending: false
    property bool _desiredDisplaysOff: false
    property bool _displayCommandTargetOff: false
    property var _savedBrightness: ({})

    signal operationStarted(string operation)
    signal operationSucceeded(string operation)
    signal operationFailed(string operation, string message)
    signal lockRequested()

    PersistentProperties {
        id: persistentState
        reloadableId: "clavis-idle-state"

        property bool inhibited: false
    }

    function setInhibited(value) {
        const requested = !!value;
        if (root.inhibited === requested)
            return;

        root.lastError = "";
        root.operationStarted("set-inhibited");
        root.inhibited = requested;
        root.operationSucceeded("set-inhibited");
    }

    function toggleInhibited() {
        root.setInhibited(!root.inhibited);
    }

    function toggle() {
        root.toggleInhibited();
    }

    function configureStage(stage, enabled, timeout, respectInhibitors = true) {
        const name = String(stage || "");
        if (["dim", "lock", "displayOff", "suspend"].indexOf(name) === -1) {
            root.lastError = "未知 Idle 阶段: " + name;
            root.operationFailed("configure-stage", root.lastError);
            return;
        }

        const normalizedTimeout = Math.max(0, Number(timeout || 0));
        root[name + "Enabled"] = !!enabled;
        root[name + "Timeout"] = normalizedTimeout;
        root[name + "RespectInhibitors"] = !!respectInhibitors;
    }

    function _monitorEnabled(stageEnabled, timeout, respectInhibitors) {
        return root.policyEnabled
            && stageEnabled
            && timeout > 0
            && !(respectInhibitors && root.inhibited);
    }

    function _setDimmed(value) {
        const requested = !!value;
        if (root.dimmed === requested)
            return;

        if (requested) {
            const saved = {};
            for (const monitor of Brightness.monitors) {
                if (!monitor || !monitor.screen)
                    continue;
                saved[monitor.screenName] = Number(monitor.brightness);
                Brightness.setBrightnessForScreen(
                    monitor.screen,
                    Math.max(0.05, Number(monitor.brightness) * root.dimFraction)
                );
            }
            root._savedBrightness = saved;
            root.dimmed = true;
            return;
        }

        const previous = root._savedBrightness;
        root._savedBrightness = {};
        root.dimmed = false;
        for (const monitor of Brightness.monitors) {
            if (!monitor || !monitor.screen || previous[monitor.screenName] === undefined)
                continue;
            Brightness.setBrightnessForScreen(monitor.screen, Number(previous[monitor.screenName]));
        }
    }

    function _requestLock() {
        if (root.lockPending)
            return;
        root.lastError = "";
        root.lockPending = true;
        root.operationStarted("lock");
        root.lockRequested();
    }

    function reportLockResult(result) {
        if (!root.lockPending)
            return;
        root.lockPending = false;
        if (result === "LOCKED" || result === "ALREADY_LOCKED") {
            root.operationSucceeded("lock");
            return;
        }
        root.lastError = "锁屏请求失败: " + String(result || "unknown");
        root.operationFailed("lock", root.lastError);
    }

    function _setDisplaysOff(value) {
        root._desiredDisplaysOff = !!value;
        if (displayPowerProcess.running)
            return;
        if (root.displaysOff === root._desiredDisplaysOff)
            return;

        root._displayCommandTargetOff = root._desiredDisplaysOff;
        root.lastError = "";
        root.operationStarted(root._displayCommandTargetOff ? "display-off" : "display-on");
        displayPowerProcess.exec([
            "niri",
            "msg",
            "action",
            root._displayCommandTargetOff ? "power-off-monitors" : "power-on-monitors"
        ]);
    }

    function _requestSuspend() {
        if (suspendProcess.running)
            return;
        root.lastError = "";
        root.operationStarted("suspend");
        suspendProcess.exec(["loginctl", "suspend"]);
    }

    IdleInhibitorSurface {
        id: inhibitorSurface
    }

    IdleInhibitor {
        window: inhibitorSurface
        enabled: root.inhibited
    }

    IdleMonitor {
        id: dimMonitor
        timeout: Math.max(1, root.dimTimeout)
        respectInhibitors: root.dimRespectInhibitors
        enabled: root._monitorEnabled(root.dimEnabled, root.dimTimeout, root.dimRespectInhibitors)

        onIsIdleChanged: root._setDimmed(isIdle)
    }

    IdleMonitor {
        id: lockMonitor
        timeout: Math.max(1, root.lockTimeout)
        respectInhibitors: root.lockRespectInhibitors
        enabled: root._monitorEnabled(root.lockEnabled, root.lockTimeout, root.lockRespectInhibitors)

        onIsIdleChanged: {
            if (isIdle)
                root._requestLock();
        }
    }

    IdleMonitor {
        id: displayOffMonitor
        timeout: Math.max(1, root.displayOffTimeout)
        respectInhibitors: root.displayOffRespectInhibitors
        enabled: root._monitorEnabled(
            root.displayOffEnabled,
            root.displayOffTimeout,
            root.displayOffRespectInhibitors
        )

        onIsIdleChanged: root._setDisplaysOff(isIdle)
    }

    IdleMonitor {
        id: suspendMonitor
        timeout: Math.max(1, root.suspendTimeout)
        respectInhibitors: root.suspendRespectInhibitors
        enabled: root._monitorEnabled(
            root.suspendEnabled,
            root.suspendTimeout,
            root.suspendRespectInhibitors
        )

        onIsIdleChanged: {
            if (isIdle)
                root._requestSuspend();
        }
    }

    Process {
        id: displayPowerProcess

        onExited: exitCode => {
            const operation = root._displayCommandTargetOff ? "display-off" : "display-on";
            if (exitCode === 0) {
                root.displaysOff = root._displayCommandTargetOff;
                root.operationSucceeded(operation);
            } else {
                root.lastError = "niri 显示器电源动作失败，退出码 " + exitCode;
                root.operationFailed(operation, root.lastError);
            }

            if (root.displaysOff !== root._desiredDisplaysOff)
                Qt.callLater(root._setDisplaysOff, root._desiredDisplaysOff);
        }
    }

    Process {
        id: suspendProcess

        onExited: exitCode => {
            if (exitCode === 0) {
                root.operationSucceeded("suspend");
                return;
            }
            root.lastError = "systemd-logind 挂起动作失败，退出码 " + exitCode;
            root.operationFailed("suspend", root.lastError);
        }
    }

    onInhibitedChanged: {
        if (inhibited) {
            root._setDimmed(false);
            root._setDisplaysOff(false);
        }
    }

    Component.onDestruction: {
        root._setDimmed(false);
        if (root.displaysOff)
            Quickshell.execDetached(["niri", "msg", "action", "power-on-monitors"]);
    }
}
