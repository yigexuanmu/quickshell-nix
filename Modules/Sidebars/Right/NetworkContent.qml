import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import Quickshell
import qs.Services
import qs.Common
import qs.Widgets.common

WidgetPanel {
    id: root
    title: "WI-FI"
    icon: "wifi"
    closeAction: () => WidgetState.qsOpen = false

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "network"
    property bool scanLeaseAcquired: false
    property string mdFont: "Material Symbols Outlined"

    function updateScanLease() {
        if (isActive && !scanLeaseAcquired) {
            NetworkService.acquireScan("right-sidebar-network");
            scanLeaseAcquired = true;
        } else if (!isActive && scanLeaseAcquired) {
            NetworkService.releaseScan("right-sidebar-network");
            scanLeaseAcquired = false;
        }
    }

    onIsActiveChanged: updateScanLease()
    Component.onCompleted: updateScanLease()
    Component.onDestruction: {
        if (scanLeaseAcquired)
            NetworkService.releaseScan("right-sidebar-network");
    }

    headerTools: RowLayout {
        spacing: 12

        Rectangle {
            id: mainSwitch
            width: 44; height: 24; radius: 12 
            color: NetworkService.wifiEnabled ? Appearance.colors.colPrimary : "transparent"
            border.width: NetworkService.wifiEnabled ? 0 : 2
            border.color: Appearance.colors.colOutline
            enabled: NetworkService.available && NetworkService.wifiHardwareEnabled
            opacity: enabled ? 1 : 0.5
            Behavior on color { ColorAnimation { duration: 250 } }
            
            Rectangle { 
                width: NetworkService.wifiEnabled ? 16 : 12
                height: NetworkService.wifiEnabled ? 16 : 12
                radius: width / 2
                x: NetworkService.wifiEnabled ? parent.width - width - 4 : 6
                anchors.verticalCenter: parent.verticalCenter
                color: NetworkService.wifiEnabled ? Appearance.colors.colOnPrimary : Appearance.colors.colOutline
                
                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } 
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }

                Text {
                    anchors.centerIn: parent
                    text: "check"
                    font.family: root.mdFont
                    font.pixelSize: 12 // 图标等比例缩小
                    font.bold: true
                    color: Appearance.colors.colPrimary
                    opacity: NetworkService.wifiEnabled ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
            
            MouseArea { 
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: NetworkService.toggleWifi()
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: NetworkService.wifiScanning ? 4 : 0
            opacity: NetworkService.wifiScanning ? 1 : 0
            indeterminate: true
            Material.accent: Appearance.colors.colPrimary

            Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Label {
            Layout.fillWidth: true
            visible: text.length > 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: NetworkService.lastError.length > 0
                ? Appearance.colors.colError
                : Appearance.colors.colOnLayer1
            text: {
                if (NetworkService.lastError.length > 0)
                    return NetworkService.lastError;
                if (!NetworkService.available)
                    return "NetworkManager 不可用";
                if (!NetworkService.wifiAvailable)
                    return "未检测到 Wi-Fi 设备";
                if (!NetworkService.wifiEnabled)
                    return "Wi-Fi 已关闭";
                if (NetworkService.friendlyWifiNetworks.length === 0)
                    return NetworkService.wifiScanning ? "正在扫描网络…" : "没有可用网络";
                return "";
            }
        }

        StyledListView {
            id: wifiList

            Layout.fillWidth: true
            Layout.fillHeight: true
            model: NetworkService.friendlyWifiNetworks

            delegate: WifiNetworkItem {
                required property var modelData
                width: ListView.view.width
                wifiNetwork: modelData
            }
        }
    }

    component WifiNetworkItem: Rectangle {
        id: itemRoot

        required property var wifiNetwork
        readonly property bool networkActive: wifiNetwork && wifiNetwork.active
        readonly property bool networkSecure: wifiNetwork && wifiNetwork.isSecure
        readonly property bool networkAskingPassword: wifiNetwork && wifiNetwork.askingPassword
        readonly property int networkStrength: wifiNetwork ? wifiNetwork.strength : 0
        readonly property string networkSsid: wifiNetwork ? wifiNetwork.ssid : "未知网络"
        readonly property bool publicPortalShown: itemRoot.networkActive && NetworkService.captivePortal
        readonly property real verticalPadding: 12
        readonly property real baseHeight: networkRow.implicitHeight + itemRoot.verticalPadding * 2
        readonly property real passwordPromptTargetHeight: itemRoot.networkAskingPassword ? passwordPromptContent.implicitHeight + 8 : 0
        readonly property real publicPortalTargetHeight: itemRoot.publicPortalShown ? publicPortalContent.implicitHeight + 8 : 0

        height: itemRoot.baseHeight + itemRoot.passwordPromptTargetHeight + itemRoot.publicPortalTargetHeight
        radius: 10
        clip: true
        color: {
            if (itemRoot.networkActive || itemRoot.networkAskingPassword)
                return Appearance.colors.colLayer3;
            if (mouseArea.pressed)
                return Appearance.colors.colLayer2Active;
            if (mouseArea.containsMouse)
                return Appearance.colors.colLayer2Hover;
            return "transparent";
        }
        enabled: !(NetworkService.wifiConnectTarget
                   && NetworkService.wifiConnectTarget.ssid === itemRoot.networkSsid
                   && !itemRoot.networkActive)

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on height {
            ElementMoveAnimation {}
        }
        Behavior on y {
            ElementMoveAnimation {}
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: NetworkService.connectToWifiNetwork(itemRoot.wifiNetwork)
        }

        ColumnLayout {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 14
                rightMargin: 14
                topMargin: itemRoot.verticalPadding
            }
            spacing: 0

            RowLayout {
                id: networkRow

                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: itemRoot.networkStrength > 80 ? "signal_wifi_4_bar" : itemRoot.networkStrength > 60 ? "network_wifi_3_bar" : itemRoot.networkStrength > 40 ? "network_wifi_2_bar" : itemRoot.networkStrength > 20 ? "network_wifi_1_bar" : "signal_wifi_0_bar"
                    font.family: root.mdFont
                    font.pixelSize: 24
                    color: itemRoot.networkActive ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: itemRoot.networkSsid
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.bold: true
                        font.pixelSize: 14
                        color: itemRoot.networkActive ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                    }
                }

                Text {
                    visible: itemRoot.networkSecure || itemRoot.networkActive
                        || (NetworkService.wifiConnectTarget
                            && NetworkService.wifiConnectTarget.ssid === itemRoot.networkSsid)
                    text: itemRoot.networkActive
                        ? "check"
                        : (NetworkService.wifiConnectTarget
                            && NetworkService.wifiConnectTarget.ssid === itemRoot.networkSsid)
                            ? "settings_ethernet"
                            : "lock"
                    font.family: root.mdFont
                    font.pixelSize: 22
                    color: itemRoot.networkActive ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Item {
                id: passwordPromptClip

                Layout.fillWidth: true
                Layout.preferredHeight: itemRoot.passwordPromptTargetHeight
                visible: itemRoot.networkAskingPassword || height > 0
                opacity: itemRoot.networkAskingPassword ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight {
                    ElementMoveAnimation {}
                }
                Behavior on height {
                    ElementMoveAnimation {}
                }
                Behavior on opacity {
                    ElementMoveAnimation {}
                }

                ColumnLayout {
                    id: passwordPromptContent

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: 8
                    }
                    spacing: 8

                    MaterialTextField {
                        id: passwordField
                        Layout.fillWidth: true
                        placeholderText: "密码"
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        onAccepted: {
                            const password = text;
                            text = "";
                            NetworkService.changePassword(itemRoot.wifiNetwork, password);
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item { Layout.fillWidth: true }
                        DialogActionButton {
                            text: "取消"
                            onClicked: {
                                passwordField.text = "";
                                passwordField.focus = false;
                                NetworkService.cancelPasswordRequest(itemRoot.wifiNetwork);
                            }
                        }
                        DialogActionButton {
                            text: "连接"
                            onClicked: {
                                const password = passwordField.text;
                                passwordField.text = "";
                                passwordField.focus = false;
                                NetworkService.changePassword(itemRoot.wifiNetwork, password);
                            }
                        }
                    }
                }
            }

            Item {
                id: publicPortalClip

                Layout.fillWidth: true
                Layout.preferredHeight: itemRoot.publicPortalTargetHeight
                visible: itemRoot.publicPortalShown || height > 0
                opacity: itemRoot.publicPortalShown ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight {
                    ElementMoveAnimation {}
                }
                Behavior on height {
                    ElementMoveAnimation {}
                }
                Behavior on opacity {
                    ElementMoveAnimation {}
                }

                ColumnLayout {
                    id: publicPortalContent

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: 8
                    }

                    DialogActionButton {
                        Layout.fillWidth: true
                        text: "打开网络门户"
                        filled: true
                        onClicked: {
                            NetworkService.openPublicWifiPortal();
                            WidgetState.qsOpen = false;
                        }
                    }
                }
            }
        }
    }
}
