import QtQuick
import QtQuick.Layouts
import org.ativos.oobe

Item {
    id: root

    property var summary: [
        { label: "Time zone", value: Backend.currentTimezone() },
        { label: "Keyboard", value: Backend.currentKeyboardLayout().toUpperCase() },
        { label: "Computer name", value: Backend.currentHostname() },
        { label: "Game Mode", value: Backend.gameModeEnabled() ? "On" : "Off" },
        { label: "Performance profile", value: Backend.performanceProfile() }
    ]

    Component.onCompleted: window.canContinue = true

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 22

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/qt/qml/org/ativos/oobe/assets/logo.png"
            fillMode: Image.PreserveAspectFit
            Layout.preferredWidth: 72
            Layout.preferredHeight: 72
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "You're all set"
            color: Theme.textPrimary
            font.pixelSize: 28
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 460
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "AtivOS is ready to go. Welcome aboard, " + Backend.currentUser() + "."
            color: Theme.textSecondary
            font.pixelSize: 14
            lineHeight: 1.3
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 380
            radius: Theme.radiusCard
            color: Theme.cardBg
            implicitHeight: summaryCol.implicitHeight + 24

            ColumnLayout {
                id: summaryCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 18
                spacing: 8

                Repeater {
                    model: root.summary
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: modelData.label; color: Theme.textSecondary; font.pixelSize: 12; Layout.fillWidth: true }
                        Text { text: modelData.value; color: Theme.textPrimary; font.pixelSize: 12; font.bold: true }
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Everything here can be changed later in System Settings."
            color: Theme.textSecondary
            font.pixelSize: 11
        }
    }
}
