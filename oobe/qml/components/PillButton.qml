import QtQuick
import QtQuick.Controls
import org.ativos.oobe

Button {
    id: control

    property bool primary: false
    property bool flat: false
    property color baseColor: primary ? Theme.accent : (flat ? "transparent" : Theme.cardBg)
    property color textColor: primary ? Theme.onAccent : Theme.textPrimary
    property real pillHeight: 40
    property real pillWidth: Math.max(implicitContentWidth + 40, 96)

    implicitWidth: pillWidth
    implicitHeight: pillHeight
    hoverEnabled: true
    scale: control.pressed ? Theme.pressScale : (control.hovered ? Theme.hoverScale : 1.0)

    Behavior on scale {
        NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic }
    }

    background: Rectangle {
        id: bg
        radius: Theme.radiusPill
        color: {
            if (!control.enabled) return control.flat ? "transparent" : Theme.divider
            if (control.flat) return control.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
            return control.hovered ? Qt.lighter(control.baseColor, primary ? 1.08 : 1.25) : control.baseColor
        }

        Behavior on color {
            ColorAnimation { duration: Theme.durationFast }
        }

        // subtle top highlight to sell the glassy Tahoe look
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height / 2
            radius: parent.radius
            color: "white"
            opacity: control.primary ? 0.10 : 0.04
        }
    }

    contentItem: Text {
        text: control.text
        color: control.enabled ? control.textColor : Theme.textSecondary
        font.pixelSize: 14
        font.bold: control.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
