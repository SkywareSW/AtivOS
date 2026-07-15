import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe

ApplicationWindow {
    id: window
    width: 840
    height: 560
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: Theme.bg
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StackView {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            initialItem: pages[0].source

            replaceEnter: Transition {
                PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
                PropertyAnimation { property: "x"; from: 24; to: 0; duration: 220; easing.type: Easing.OutCubic }
            }
            replaceExit: Transition {
                PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: 160 }
            }
        }

        // ---- bottom nav bar ------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            height: 76
            color: Theme.bgElevated

            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.divider }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 28
                anchors.rightMargin: 28
                spacing: 16

                Button {
                    text: "Back"
                    flat: true
                    visible: pageIndex > 0 && pageIndex < pages.length - 1
                    onClicked: goBack()
                    contentItem: Text {
                        text: parent.text
                        color: Theme.textSecondary
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: Rectangle { color: "transparent" }
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter
                    visible: pageIndex < pages.length - 1
                    Repeater {
                        model: pages.length
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: index === pageIndex ? Theme.accent : Theme.divider
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    id: nextButton
                    text: pageIndex === pages.length - 2 ? "Finish Setup"
                        : pageIndex === pages.length - 1 ? "Get Started"
                        : "Continue"
                    enabled: canContinue
                    onClicked: goNext()

                    background: Rectangle {
                        radius: 8
                        color: nextButton.enabled ? Theme.accent : Theme.divider
                        implicitWidth: 140
                        implicitHeight: 38
                    }
                    contentItem: Text {
                        text: nextButton.text
                        color: nextButton.enabled ? "#0d1117" : Theme.textSecondary
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
