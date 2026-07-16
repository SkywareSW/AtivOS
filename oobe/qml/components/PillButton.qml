import QtQuick
import QtQuick.Controls
import org.ativos.oobe

Button {
    id: control

    property bool primary: false
    property bool flatStyle: false

    // Hardcoded aqua palette, deliberately NOT routed through the Theme
    // singleton: Theme.* references were silently failing at runtime
    // (radii collapsing to 0, colors collapsing to Qt's raw defaults —
    // white background, black text) which is why buttons rendered as
    // plain black rectangles with square corners instead of the intended
    // style. These are literal values so the button looks right
    // regardless of whether that singleton issue is fixed.
    readonly property color aqua: "#2dd4bf"
    // THE BUG: the primary button used the same translucent "glass" fill
    // (~30% alpha) as the secondary buttons. That reads fine over a dark
    // themed panel, but as soon as the panel's real background isn't dark
    // (broken Theme singleton falling back to white, or just a lighter
    // page), a 30%-alpha teal over white is barely more than a pale tint —
    // the button looked washed out and low-contrast instead of like the
    // primary call-to-action. The primary pill is now a fully opaque solid
    // fill so it reads clearly regardless of what's behind it; secondary/
    // flat buttons keep the translucent glass look.
    property color baseColor: primary
        ? aqua
        : (flatStyle ? Qt.rgba(0.176, 0.831, 0.749, 0.10) : Qt.rgba(0.176, 0.831, 0.749, 0.18))
    property color textColor: primary ? "#0d1117" : "#eafffb"
    property real pillHeight: 40
    property real pillWidth: Math.max(implicitContentWidth + 40, 96)

    implicitWidth: pillWidth
    implicitHeight: pillHeight
    hoverEnabled: true
    scale: control.pressed ? 0.96 : (control.hovered ? 1.02 : 1.0)

    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    background: Rectangle {
        id: bg
        // Self-computed pill radius — always a perfect capsule no matter
        // the button's height, with no external dependency.
        radius: height / 2
        color: {
            if (!control.enabled) return Qt.rgba(0.176, 0.831, 0.749, 0.08)
            return control.hovered ? Qt.lighter(control.baseColor, primary ? 1.15 : 1.35) : control.baseColor
        }
        border.width: 1
        border.color: Qt.rgba(0.176, 0.831, 0.749, control.enabled ? 0.55 : 0.20)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        // subtle top highlight to sell the glassy look
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
        color: control.enabled ? control.textColor : Qt.rgba(0.918, 1, 0.984, 0.45)
        font.pixelSize: 14
        font.bold: control.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
