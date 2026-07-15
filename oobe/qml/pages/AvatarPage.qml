import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.ativos.oobe

Item {
    id: root
    property url avatarPath: ""
    property bool saved: false

    Component.onCompleted: window.canContinue = true

    FileDialog {
        id: fileDialog
        title: "Choose a picture"
        nameFilters: ["Images (*.png *.jpg *.jpeg)"]
        onAccepted: {
            root.avatarPath = fileDialog.selectedFile
            root.saved = Backend.setAvatar(fileDialog.selectedFile)
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Add a picture"
            color: Theme.textPrimary
            font.pixelSize: 26
            font.bold: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "This appears on the login screen and in System Settings. Optional."
            color: Theme.textSecondary
            font.pixelSize: 13
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 140; height: 140; radius: 70
            color: Theme.cardBg
            border.width: 2
            border.color: root.saved ? Theme.accent : Theme.divider
            clip: true

            Image {
                anchors.fill: parent
                visible: root.avatarPath != ""
                source: root.avatarPath
                fillMode: Image.PreserveAspectCrop
            }

            Text {
                anchors.centerIn: parent
                visible: root.avatarPath == ""
                text: "＋"
                color: Theme.textSecondary
                font.pixelSize: 40
            }

            MouseArea {
                anchors.fill: parent
                onClicked: fileDialog.open()
            }
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            text: root.avatarPath == "" ? "Choose Picture…" : "Choose a Different Picture…"
            onClicked: fileDialog.open()
            background: Rectangle { radius: 8; color: Theme.divider; implicitWidth: 220; implicitHeight: 36 }
            contentItem: Text {
                text: parent.text
                color: Theme.textPrimary
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
