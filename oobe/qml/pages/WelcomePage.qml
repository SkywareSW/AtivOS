import QtQuick
import QtQuick.Layouts
import org.ativos.oobe

Item {
    id: root

    Component.onCompleted: window.canContinue = true

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 28

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/qt/qml/org/ativos/oobe/assets/logo.png"
            fillMode: Image.PreserveAspectFit
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Welcome to AtivOS"
                color: Theme.textPrimary
                font.pixelSize: 34
                font.bold: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Let's get your system set up, " + Backend.currentUser() + "."
                color: Theme.textSecondary
                font.pixelSize: 15
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 440
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "This will only take a minute. You can change any of these settings later in System Settings."
            color: Theme.textSecondary
            font.pixelSize: 13
            lineHeight: 1.3
        }
    }
}
