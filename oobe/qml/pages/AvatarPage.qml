import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.ativos.oobe
import "../components"

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
            id: avatarCircle
            Layout.alignment: Qt.AlignHCenter
            width: 140; height: 140; radius: 70
            color: Theme.cardBg
            border.width: 2
            border.color: root.saved ? Theme.accent : Theme.divider
            clip: true
            scale: avatarArea.pressed ? Theme.pressScale : (avatarArea.containsMouse ? Theme.hoverScale : 1.0)

            Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: Theme.durationMedium } }

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
                id: avatarArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: fileDialog.open()
            }
        }

        PillButton {
            Layout.alignment: Qt.AlignHCenter
            flat: true
            pillWidth: 240
            text: root.avatarPath == "" ? "Choose Picture…" : "Choose a Different Picture…"
            onClicked: fileDialog.open()
        }
    }
}
