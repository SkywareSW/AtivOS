import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe
import "components"

ApplicationWindow {
    id: window
    width: 840
    height: 560
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: "AtivOS Setup Assistant"

    Component.onCompleted: {
        x = (Screen.width - width) / 2
        y = (Screen.height - height) / 2
    }

    property var pages: [
        { source: "pages/WelcomePage.qml" },
        { source: "pages/LanguagePage.qml" },
        { source: "pages/AppearancePage.qml" },
        { source: "pages/NetworkPage.qml" },
        { source: "pages/PrivacyPage.qml" },
        { source: "pages/AvatarPage.qml" },
        { source: "pages/FinishPage.qml" }
    ]
    property int pageIndex: 0
    property bool canContinue: true

    function goNext() {
        if (pageIndex < pages.length - 1) {
            pageIndex += 1
            canContinue = true
            stack.replace(pages[pageIndex].source)
        } else {
            Backend.finish()
        }
    }

    function goBack() {
        if (pageIndex > 0) {
            pageIndex -= 1
            canContinue = true
            stack.replace(pages[pageIndex].source)
        }
    }

    // ---- soft drop shadow behind the rounded panel --------------------
    // Hand-rolled (no extra Qt module / build dependency needed): a few
    // stacked, progressively larger, near-transparent rounded outlines
    // under the real panel approximate a soft blur falloff.
    Item {
        anchors.fill: parent
        anchors.margins: -20
        z: -1
        Repeater {
            model: 8
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - (7 - index) * 5
                height: parent.height - (7 - index) * 5
                radius: 22 + (parent.width - width) / 2
                color: "transparent"
                border.width: 3
                border.color: Qt.rgba(0, 0, 0, 0.05 - index * 0.004)
            }
        }
    }

    // ---- the rounded, clipped panel that holds everything -------------
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 22
        color: Theme.bg
        clip: true
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)

        // Frameless window has no OS titlebar to drag by, so the top strip
        // (above any page content) doubles as one.
        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 32
            onPressed: window.startSystemMove()
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            StackView {
                id: stack
                Layout.fillWidth: true
                Layout.fillHeight: true
                initialItem: pages[0].source

                replaceEnter: Transition {
                    PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationMedium }
                    PropertyAnimation { property: "x"; from: 32; to: 0; duration: Theme.durationSlow; easing.type: Easing.OutCubic }
                }
                replaceExit: Transition {
                    PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationFast }
                    PropertyAnimation { property: "x"; from: 0; to: -24; duration: Theme.durationFast; easing.type: Easing.InCubic }
                }
            }

            // ---- bottom nav bar --------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                height: 76
                color: Theme.bgElevated
                radius: panel.radius

                // THE BUG: this bar sits flush against the panel's rounded
                // bottom edge. `clip: true` on the panel only clips to its
                // bounding box, not its rounded shape, so this bar's own
                // (previously square) corners painted straight over where
                // the panel's rounded bottom-left/bottom-right corners
                // should have shown, making the whole window look
                // rounded on top and square on the bottom. Fix: round this
                // rectangle too, then mask its top corners back to square
                // with a plain same-color rectangle over the top half —
                // leaves only the bottom two corners rounded.
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.radius
                    color: parent.color
                }

                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.divider }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    spacing: 16

                    PillButton {
                        text: "Back"
                        flatStyle: true
                        pillWidth: 88
                        visible: pageIndex > 0 && pageIndex < pages.length - 1
                        onClicked: goBack()
                    }

                    Item { Layout.fillWidth: true }

                    // animated capsule step indicator: the active step
                    // expands into a pill instead of just changing color
                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter
                        visible: pageIndex < pages.length - 1
                        Repeater {
                            model: pages.length
                            Rectangle {
                                width: index === pageIndex ? 20 : 6
                                height: 6
                                radius: 3
                                color: index === pageIndex ? Theme.accent : Theme.divider
                                Behavior on width { NumberAnimation { duration: Theme.durationMedium; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    PillButton {
                        id: nextButton
                        primary: true
                        enabled: canContinue
                        pillWidth: 140
                        text: pageIndex === pages.length - 2 ? "Finish Setup"
                            : pageIndex === pages.length - 1 ? "Get Started"
                            : "Continue"
                        onClicked: goNext()
                    }
                }
            }
        }
    }
}
