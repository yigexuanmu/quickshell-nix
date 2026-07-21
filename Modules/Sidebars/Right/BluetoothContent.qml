import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

WidgetPanel {
    id: root

    title: "蓝牙"
    icon: "bluetooth"
    showBackButton: true
    backAction: () => WidgetState.qsView = "settings"

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "bluetooth"
    property bool discoveryLeaseAcquired: false
    property bool discoveryPulse: false
    property var pendingForgetDevice: null
    readonly property string stateMessage: {
        if (BluetoothService.lastError.length > 0)
            return BluetoothService.lastError;
        if (!BluetoothService.available)
            return "未检测到蓝牙适配器或 BlueZ 不可用";
        if (!BluetoothService.enabled)
            return "蓝牙已关闭";
        if (BluetoothService.devices.length === 0 && !BluetoothService.discovering)
            return "尚未发现蓝牙设备";
        return "";
    }

    function updateDiscoveryLease() {
        if (isActive && !discoveryLeaseAcquired) {
            BluetoothService.acquireDiscovery("right-sidebar-bluetooth");
            discoveryLeaseAcquired = true;
        } else if (!isActive && discoveryLeaseAcquired) {
            BluetoothService.releaseDiscovery("right-sidebar-bluetooth");
            discoveryLeaseAcquired = false;
            discoveryPulse = false;
            discoveryPulseTimer.stop();
        }
    }

    function restartDiscoveryLease() {
        if (!root.discoveryLeaseAcquired || !BluetoothService.enabled)
            return;
        BluetoothService.releaseDiscovery("right-sidebar-bluetooth");
        BluetoothService.acquireDiscovery("right-sidebar-bluetooth");
        discoveryPulse = true;
        discoveryPulseTimer.restart();
    }

    function iconForDevice(device) {
        const icon = String(device && device.icon || "").toLowerCase();
        if (icon.indexOf("head") >= 0 || icon.indexOf("audio") >= 0)
            return "headphones";
        if (icon.indexOf("speaker") >= 0)
            return "speaker";
        if (icon.indexOf("keyboard") >= 0)
            return "keyboard";
        if (icon.indexOf("mouse") >= 0 || icon.indexOf("input") >= 0)
            return "mouse";
        if (icon.indexOf("phone") >= 0)
            return "smartphone";
        if (icon.indexOf("computer") >= 0)
            return "computer";
        return "bluetooth";
    }

    function deviceSupportingText(device) {
        const states = [];
        if (device.blocked)
            states.push("已阻止");
        else if (device.pairing)
            states.push("正在配对");
        else if (device.connected)
            states.push("已连接");
        else if (device.paired || device.bonded)
            states.push("已配对");
        else
            states.push("可用设备");
        if (device.trusted)
            states.push("受信任");
        if (device.batteryAvailable)
            states.push("电量 " + device.batteryLevel + "%");
        return states.join(" · ");
    }

    onIsActiveChanged: updateDiscoveryLease()
    Component.onCompleted: updateDiscoveryLease()
    Component.onDestruction: {
        if (discoveryLeaseAcquired)
            BluetoothService.releaseDiscovery("right-sidebar-bluetooth");
    }

    Timer {
        id: discoveryPulseTimer
        interval: 1200
        repeat: false
        onTriggered: root.discoveryPulse = false
    }

    headerTools: RowLayout {
        spacing: Appearance.spacing.xSmall

        ToolButton {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            enabled: BluetoothService.available
                && BluetoothService.enabled
                && !BluetoothService.busy
            hoverEnabled: true
            Accessible.name: "重新扫描蓝牙设备"
            onClicked: root.restartDiscoveryLease()

            background: Rectangle {
                radius: Appearance.rounding.full
                color: parent.down
                    ? Appearance.colors.colLayer2Active
                    : parent.hovered ? Appearance.colors.colLayer2Hover : "transparent"
            }

            contentItem: MaterialSymbol {
                text: "refresh"
                iconSize: 21
                color: Appearance.colors.colOnLayer2

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: root.discoveryPulse
                }
            }
        }

        StyledSwitch {
            scale: 0.8
            checked: BluetoothService.enabled
            enabled: BluetoothService.available && !BluetoothService.busy
            Accessible.name: "蓝牙开关"
            onToggled: BluetoothService.setBluetoothEnabled(checked)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Appearance.spacing.small

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: BluetoothService.busy ? 4 : 0
            opacity: BluetoothService.busy ? 1 : 0
            indeterminate: true
            Material.accent: Appearance.colors.colPrimary

            Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
            Behavior on opacity { ElementMoveAnimation {} }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.stateMessage.length > 0
            tone: BluetoothService.lastError.length > 0 ? "error" : "info"
            message: root.stateMessage
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: bluetoothContent.implicitHeight

            ColumnLayout {
                id: bluetoothContent

                width: parent.width - Appearance.spacing.small
                spacing: Appearance.spacing.small

                SettingsSection {
                    Layout.fillWidth: true
                    title: "适配器"
                    supportingText: BluetoothService.discovering
                        ? "正在查找附近设备"
                        : BluetoothService.enabled ? "设备发现已暂停" : "打开蓝牙后可开始发现"

                    Repeater {
                        model: BluetoothService.adapters

                        SettingsRow {
                            required property var modelData

                            Layout.fillWidth: true
                            iconName: modelData.blocked ? "bluetooth_disabled" : "settings_bluetooth"
                            title: modelData.name || modelData.id || "蓝牙适配器"
                            supportingText: modelData.blocked
                                ? "已被 rfkill 阻止"
                                : modelData.enabled ? modelData.state : "已关闭"
                            highlighted: modelData.enabled

                            trailing: StyledSwitch {
                                scale: 0.72
                                checked: modelData.enabled
                                enabled: !modelData.blocked && !BluetoothService.busy
                                Accessible.name: "切换适配器 " + (modelData.name || modelData.id)
                                onToggled: BluetoothService.setAdapterEnabled(modelData, checked)
                            }
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: BluetoothService.available
                        iconName: "visibility"
                        title: "允许被发现"
                        supportingText: "让附近设备可以找到这台电脑"
                        enabled: BluetoothService.enabled

                        trailing: StyledSwitch {
                            scale: 0.72
                            checked: BluetoothService.discoverable
                            enabled: BluetoothService.enabled && !BluetoothService.busy
                            Accessible.name: "蓝牙可发现"
                            onToggled: BluetoothService.setDiscoverable(checked)
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: BluetoothService.available
                        iconName: "handshake"
                        title: "允许配对"
                        supportingText: "接受官方模块支持的配对请求"
                        enabled: BluetoothService.enabled

                        trailing: StyledSwitch {
                            scale: 0.72
                            checked: BluetoothService.pairable
                            enabled: BluetoothService.enabled && !BluetoothService.busy
                            Accessible.name: "蓝牙可配对"
                            onToggled: BluetoothService.setPairable(checked)
                        }
                    }
                }

                DeviceSection {
                    Layout.fillWidth: true
                    visible: BluetoothService.enabled && BluetoothService.connectedDevices.length > 0
                    sectionTitle: "已连接"
                    devicesModel: BluetoothService.connectedDevices
                    category: "connected"
                }

                DeviceSection {
                    Layout.fillWidth: true
                    visible: BluetoothService.enabled && BluetoothService.pairedDevices.length > 0
                    sectionTitle: "已配对"
                    devicesModel: BluetoothService.pairedDevices
                    category: "paired"
                }

                DeviceSection {
                    Layout.fillWidth: true
                    visible: BluetoothService.enabled && BluetoothService.availableDevices.length > 0
                    sectionTitle: "可用设备"
                    devicesModel: BluetoothService.availableDevices
                    category: "available"
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Appearance.spacing.small
                }
            }
        }
    }

    Dialog {
        id: forgetDialog

        modal: true
        width: Math.min(320, root.width - 48)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        padding: Appearance.spacing.medium
        Material.theme: Material.System
        Material.accent: Appearance.colors.colPrimary

        background: Rectangle {
            radius: Appearance.rounding.veryLarge
            color: Appearance.colors.colSurfaceContainerHigh
        }

        header: Text {
            text: "遗忘蓝牙设备"
            color: Appearance.colors.colOnLayer2
            font.family: Sizes.fontFamily
            font.pixelSize: 18
            font.weight: Font.DemiBold
            leftPadding: Appearance.spacing.medium
            rightPadding: Appearance.spacing.medium
            topPadding: Appearance.spacing.medium
        }

        contentItem: Text {
            text: root.pendingForgetDevice
                ? "将删除“" + root.pendingForgetDevice.name + "”的配对信息。"
                : ""
            color: Appearance.colors.colOnLayer1
            font.family: Sizes.fontFamily
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }

        footer: RowLayout {
            spacing: Appearance.spacing.small

            Item { Layout.fillWidth: true }
            DialogActionButton {
                text: "取消"
                onClicked: {
                    forgetDialog.close();
                    root.pendingForgetDevice = null;
                }
            }
            DialogActionButton {
                text: "遗忘"
                filled: true
                onClicked: {
                    const target = root.pendingForgetDevice;
                    forgetDialog.close();
                    root.pendingForgetDevice = null;
                    if (target)
                        BluetoothService.forgetDevice(target);
                }
            }
        }
    }

    component DeviceSection: SettingsSection {
        id: deviceSection

        property string sectionTitle: ""
        property var devicesModel: []
        property string category: ""

        title: sectionTitle

        Repeater {
            model: deviceSection.devicesModel

            BluetoothDeviceRow {
                required property var modelData

                Layout.fillWidth: true
                deviceData: modelData
                deviceCategory: deviceSection.category
            }
        }
    }

    component BluetoothDeviceRow: SettingsRow {
        id: deviceRow

        required property var deviceData
        property string deviceCategory: ""

        iconName: root.iconForDevice(deviceData)
        title: deviceData.name
        supportingText: root.deviceSupportingText(deviceData)
        highlighted: deviceData.connected
        enabled: !deviceData.blocked

        trailing: RowLayout {
            spacing: Appearance.spacing.xSmall

            MaterialSymbol {
                visible: deviceRow.deviceData.batteryAvailable
                text: deviceRow.deviceData.batteryLevel > 80
                    ? "battery_full"
                    : deviceRow.deviceData.batteryLevel > 30 ? "battery_4_bar" : "battery_1_bar"
                iconSize: 18
                color: Appearance.colors.colOnLayer1
            }

            DialogActionButton {
                visible: !deviceRow.deviceData.blocked
                enabled: !BluetoothService.busy
                text: deviceRow.deviceCategory === "connected"
                    ? "断开"
                    : deviceRow.deviceCategory === "paired" ? "连接" : "配对"
                filled: deviceRow.deviceCategory !== "connected"
                onClicked: {
                    if (deviceRow.deviceCategory === "connected")
                        BluetoothService.disconnectDevice(deviceRow.deviceData);
                    else if (deviceRow.deviceCategory === "paired")
                        BluetoothService.connectDevice(deviceRow.deviceData);
                    else
                        BluetoothService.pairDevice(deviceRow.deviceData);
                }
            }

            ToolButton {
                visible: deviceRow.deviceData.paired
                    || deviceRow.deviceData.bonded
                    || deviceRow.deviceData.trusted
                implicitWidth: 34
                implicitHeight: 34
                enabled: !BluetoothService.busy
                Accessible.name: "蓝牙设备操作"
                onClicked: deviceMenu.open()

                background: Rectangle {
                    radius: Appearance.rounding.full
                    color: parent.down
                        ? Appearance.colors.colLayer3Active
                        : parent.hovered ? Appearance.colors.colLayer3Hover : "transparent"
                }

                contentItem: MaterialSymbol {
                    text: "more_vert"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer2
                }

                Menu {
                    id: deviceMenu

                    Material.theme: Material.System
                    Material.accent: Appearance.colors.colPrimary

                    MenuItem {
                        text: "遗忘设备"
                        onTriggered: {
                            root.pendingForgetDevice = deviceRow.deviceData;
                            forgetDialog.open();
                        }
                    }
                }
            }
        }
    }
}
