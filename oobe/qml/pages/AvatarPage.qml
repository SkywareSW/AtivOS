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
    property var presetAvatars: Backend.availablePresetAvatars()

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
        width: Math.min(parent.width * 0.86, 460)
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
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "This appears on the login screen and in System Settings. Pick one below, or upload your own. Optional."
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
            flatStyle: true
            pillWidth: 240
            text: root.avatarPath == "" ? "Upload a Picture…" : "Upload a Different Picture…"
            onClicked: fileDialog.open()
        }

        // ---- preset picker ----------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 12
            visible: root.presetAvatars.length > 0

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Or choose one"
                color: Theme.textSecondary
                font.pixelSize: 13
            }

            Flow {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

                Repeater {
                    model: root.presetAvatars

                    Rectangle {
                        id: presetTile
                        width: 64; height: 64; radius: 32
                        color: Theme.cardBg
                        clip: true
                        border.width: 2
                        border.color: root.avatarPath == modelData ? Theme.accent : Theme.divider
                        scale: presetArea.pressed ? Theme.pressScale : (presetArea.containsMouse ? Theme.hoverScale : 1.0)

                        Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationMedium } }

                        Image {
                            anchors.fill: parent
                            source: modelData
                            fillMode: Image.PreserveAspectCrop
                        }

                        MouseArea {
                            id: presetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.avatarPath = modelData
                                root.saved = Backend.setAvatar(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
