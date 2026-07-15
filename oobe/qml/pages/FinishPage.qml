import QtQuick
import QtQuick.Layouts
import org.ativos.oobe

Item {
    id: root

    Component.onCompleted: window.canContinue = true

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/qt/qml/org/ativos/oobe/assets/logo.png"
            fillMode: Image.PreserveAspectFit
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "You're all set"
            color: Theme.textPrimary
            font.pixelSize: 30
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 420
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "AtivOS is ready to go. Welcome aboard, " + Backend.currentUser() + "."
            color: Theme.textSecondary
            font.pixelSize: 14
            lineHeight: 1.3
        }
    }
}
