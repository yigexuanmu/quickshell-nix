import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

WidgetPanel {
    id: panelRoot

    title: "空闲与保持唤醒"
    icon: "coffee"
    showBackButton: true
    backAction: () => WidgetState.qsView = "settings"

    property real pendingDimFraction: IdleService.dimFraction
    readonly property var timeoutPresetSeconds: [60, 120, 300, 600, 900, 1800, 3600, 7200]

    function formatTimeout(seconds) {
        const value = Math.max(0, Number(seconds || 0));
        if (value < 60)
            return Math.round(value) + " 秒";
        const minutes = value / 60;
        return (Math.abs(minutes - Math.round(minutes)) < 0.001
            ? Math.round(minutes)
            : minutes.toFixed(1)) + " 分钟";
    }

    function timeoutOptions(currentSeconds) {
        const values = timeoutPresetSeconds.slice();
        const current = Math.max(0, Number(currentSeconds || 0));
        if (current > 0 && values.indexOf(current) === -1)
            values.push(current);
        values.sort((a, b) => a - b);
        return values.map(value => ({
            "seconds": value,
            "label": panelRoot.formatTimeout(value)
        }));
    }

    function stageActive(name) {
        const stage = IdleService.stages.find(candidate => candidate.name === name);
        return stage ? !!stage.active : false;
    }

    function policySummary() {
        if (!IdleService.policyEnabled)
            return "自动空闲动作已暂停";
        const enabledCount = IdleService.stages.filter(stage => stage.enabled).length;
        return enabledCount + " 个阶段已启用";
    }

    Timer {
        id: dimFractionCommitTimer
        interval: 250
        repeat: false
        onTriggered: IdleService.setDimFraction(panelRoot.pendingDimFraction)
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Appearance.spacing.small

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: (!IdleService.policyReady || IdleService.busy) ? 4 : 0
            opacity: (!IdleService.policyReady || IdleService.busy) ? 1 : 0
            indeterminate: true
            Material.accent: Appearance.colors.colPrimary

            Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
            Behavior on opacity { ElementMoveAnimation {} }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: IdleService.lastError.length > 0
            tone: "error"
            message: IdleService.lastError
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: idleContent.implicitHeight

            ColumnLayout {
                id: idleContent

                width: parent.width - Appearance.spacing.small
                spacing: Appearance.spacing.small

                SettingsSection {
                    Layout.fillWidth: true
                    title: "保持唤醒"
                    supportingText: "使用 Wayland IdleInhibitor 阻止遵循 inhibitor 的空闲阶段"

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: IdleService.inhibited ? "coffee" : "bedtime"
                        title: IdleService.inhibited ? "正在保持唤醒" : "允许正常休眠"
                        supportingText: IdleService.inhibited
                            ? "调暗和显示器关闭状态会立即恢复"
                            : "空闲策略将按下方设定执行"
                        highlighted: IdleService.inhibited

                        trailing: StyledSwitch {
                            scale: 0.78
                            checked: IdleService.inhibited
                            enabled: !IdleService.busy
                            Accessible.name: "保持唤醒"
                            onToggled: IdleService.setInhibited(checked)
                        }
                    }
                }

                SettingsSection {
                    Layout.fillWidth: true
                    title: "空闲策略"
                    supportingText: "各阶段独立计时；关闭总开关不会丢失阶段配置"

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "schedule"
                        title: "启用自动空闲动作"
                        supportingText: panelRoot.policySummary()
                        highlighted: IdleService.policyEnabled

                        trailing: StyledSwitch {
                            scale: 0.78
                            checked: IdleService.policyEnabled
                            enabled: IdleService.policyReady
                            Accessible.name: "自动空闲策略"
                            onToggled: IdleService.setPolicyEnabled(checked)
                        }
                    }
                }

                StageEditor {
                    Layout.fillWidth: true
                    stageName: "dim"
                    stageTitle: "调暗屏幕"
                    stageIcon: "brightness_4"
                    stageDescription: "空闲后降低当前显示器亮度"
                    showDimFraction: true
                }

                StageEditor {
                    Layout.fillWidth: true
                    stageName: "lock"
                    stageTitle: "锁定会话"
                    stageIcon: "lock"
                    stageDescription: "触发 Clavis LockService；恢复活动不会自动解锁"
                }

                StageEditor {
                    Layout.fillWidth: true
                    stageName: "displayOff"
                    stageTitle: "关闭显示器"
                    stageIcon: "display_settings"
                    stageDescription: "通过集中封装的 niri 动作关闭并在活动后恢复显示器"
                }

                StageEditor {
                    Layout.fillWidth: true
                    stageName: "suspend"
                    stageTitle: "挂起系统"
                    stageIcon: "mode_standby"
                    stageDescription: "超时后通过 systemd-logind 挂起当前会话"
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Appearance.spacing.small
                }
            }
        }
    }

    component StageEditor: SettingsSection {
        id: stageEditor

        required property string stageName
        required property string stageTitle
        required property string stageIcon
        property string stageDescription: ""
        property bool showDimFraction: false
        property bool expanded: false
        readonly property bool stageEnabled: !!IdleService[stageName + "Enabled"]
        readonly property real stageTimeout: Number(IdleService[stageName + "Timeout"] || 0)
        readonly property bool respectInhibitors: !!IdleService[stageName + "RespectInhibitors"]

        SettingsRow {
            Layout.fillWidth: true
            iconName: stageEditor.stageIcon
            title: stageEditor.stageTitle
            supportingText: (stageEditor.stageEnabled
                ? panelRoot.formatTimeout(stageEditor.stageTimeout)
                : "已关闭")
                + (panelRoot.stageActive(stageEditor.stageName) ? " · 已触发" : "")
            interactive: true
            highlighted: stageEditor.stageEnabled && IdleService.policyEnabled
            onClicked: stageEditor.expanded = !stageEditor.expanded

            trailing: RowLayout {
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    text: stageEditor.expanded ? "expand_less" : "expand_more"
                    iconSize: 20
                    color: Appearance.colors.colOnLayer1
                }

                StyledSwitch {
                    scale: 0.72
                    checked: stageEditor.stageEnabled
                    enabled: IdleService.policyReady
                    Accessible.name: stageEditor.stageTitle
                    onToggled: IdleService.configureStage(
                        stageEditor.stageName,
                        checked,
                        stageEditor.stageTimeout,
                        stageEditor.respectInhibitors
                    )
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: stageEditor.expanded
                ? stageDetails.implicitHeight + Appearance.spacing.small
                : 0
            opacity: stageEditor.expanded ? 1 : 0
            clip: true

            Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
            Behavior on opacity { ElementMoveAnimation {} }

            ColumnLayout {
                id: stageDetails

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: Appearance.spacing.small
                    rightMargin: Appearance.spacing.small
                    topMargin: Appearance.spacing.xSmall
                }
                spacing: Appearance.spacing.small

                Text {
                    Layout.fillWidth: true
                    text: stageEditor.stageDescription
                    color: Appearance.colors.colOnLayer1
                    font.family: Sizes.fontFamily
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    Text {
                        Layout.fillWidth: true
                        text: "等待时间"
                        color: Appearance.colors.colOnLayer2
                        font.family: Sizes.fontFamily
                        font.pixelSize: 13
                    }

                    ComboBox {
                        id: timeoutCombo

                        Layout.preferredWidth: 132
                        model: panelRoot.timeoutOptions(stageEditor.stageTimeout)
                        textRole: "label"
                        valueRole: "seconds"
                        currentIndex: {
                            const options = panelRoot.timeoutOptions(stageEditor.stageTimeout);
                            return options.findIndex(option => option.seconds === stageEditor.stageTimeout);
                        }
                        enabled: IdleService.policyReady
                        Material.theme: Material.System
                        Material.accent: Appearance.colors.colPrimary
                        onActivated: IdleService.configureStage(
                            stageEditor.stageName,
                            stageEditor.stageEnabled,
                            Number(currentValue),
                            stageEditor.respectInhibitors
                        )
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "coffee"
                    title: "保持唤醒时跳过"
                    supportingText: "关闭后，此阶段不受咖啡因开关影响"

                    trailing: StyledSwitch {
                        scale: 0.68
                        checked: stageEditor.respectInhibitors
                        enabled: IdleService.policyReady
                        Accessible.name: stageEditor.stageTitle + "遵循保持唤醒"
                        onToggled: IdleService.configureStage(
                            stageEditor.stageName,
                            stageEditor.stageEnabled,
                            stageEditor.stageTimeout,
                            checked
                        )
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: stageEditor.showDimFraction
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: "调暗比例"
                            color: Appearance.colors.colOnLayer2
                            font.family: Sizes.fontFamily
                            font.pixelSize: 13
                        }

                        Text {
                            text: Math.round(IdleService.dimFraction * 100) + "%"
                            color: Appearance.colors.colPrimary
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: 12
                        }
                    }

                    MaterialAccessibleSlider {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        from: 0.1
                        to: 0.8
                        stepSize: 0.05
                        value: IdleService.dimFraction
                        showValueIndicator: true
                        accessibleName: "屏幕调暗比例"
                        valueFormatter: value => Math.round(value * 100) + "%"
                        onMoved: {
                            panelRoot.pendingDimFraction = value;
                            dimFractionCommitTimer.restart();
                        }
                    }
                }
            }
        }
    }
}
