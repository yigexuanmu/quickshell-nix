import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Common

RoundButton {
    id: root

    property bool stopping: false
    property bool canStop: true
    signal stopRequested()

    width: 44
    height: 44
    padding: 0
    enabled: canStop && !stopping
    hoverEnabled: true
    display: AbstractButton.IconOnly
    Material.theme: Material.Dark
    onClicked: stopRequested()

    background: Item {
        Rectangle {
            anchors.centerIn: parent
            width: 34
            height: 34
            radius: Appearance.rounding.full
            color: root.down
                ? Appearance.colors.colLayer2Active
                : (root.hovered
                    ? Appearance.colors.colLayer2Hover
                    : "transparent")
            border.width: 2
            border.color: root.enabled
                ? Appearance.colors.colOnSurface
                : Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.55)

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveFastEffects.duration
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: root.down ? 12 : 14
                height: width
                radius: Appearance.rounding.extraSmall
                color: Appearance.colors.colError
                opacity: root.stopping ? 0.32 : 1

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }
            }

            BusyIndicator {
                anchors.centerIn: parent
                width: 24
                height: 24
                running: root.stopping
                visible: running
            }
        }
    }

    contentItem: Item {}

    ToolTip.visible: hovered
    ToolTip.text: stopping ? "正在完成录音" : "停止录音"
    ToolTip.delay: 500
}
