import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe

Item {
    id: root
    property bool darkMode: true
    property string accentHex: "#5aa6ff"
    property var accentOptions: ["#5aa6ff", "#7ad3a1", "#e0b45a", "#d97a8c", "#b98af0", "#5ad1c9"]

    function apply() {
        Backend.applyAppearance(darkMode, accentHex)
    }

    onDarkModeChanged: apply()
    onAccentHexChanged: apply()
    Component.onCompleted: {
        window.canContinue = true
        apply()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 56
        spacing: 28

        Text {
            text: "Appearance"
            color: Theme.textPrimary
            font.pixelSize: 26
            font.bold: true
        }
        Text {
            text: "Pick a look for your desktop. You can switch this anytime in System Settings."
            color: Theme.textSecondary
            font.pixelSize: 13
        }

        RowLayout {
            spacing: 20
            Layout.topMargin: 8

            // Dark option
            Rectangle {
                width: 220; height: 140; radius: Theme.radiusCard
                color: "#141517"
                border.width: root.darkMode ? 2 : 1
                border.color: root.darkMode ? Theme.accent : Theme.divider
                scale: darkArea.pressed ? Theme.pressScale : (darkArea.containsMouse ? Theme.hoverScale : 1.0)

                Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: Theme.durationMedium } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    Rectangle { Layout.fillWidth: true; height: 12; radius: 3; color: "#2a2b30" }
                    Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: 6; color: "#1b1c20" }
                    Text { text: "Dark"; color: Theme.textPrimary; font.pixelSize: 13; font.bold: true }
                }
                MouseArea { id: darkArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.darkMode = true }
            }

            // Light option
            Rectangle {
                width: 220; height: 140; radius: Theme.radiusCard
                color: "#f4f5f7"
                border.width: !root.darkMode ? 2 : 1
                border.color: !root.darkMode ? Theme.accent : Theme.divider
                scale: lightArea.pressed ? Theme.pressScale : (lightArea.containsMouse ? Theme.hoverScale : 1.0)

                Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: Theme.durationMedium } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    Rectangle { Layout.fillWidth: true; height: 12; radius: 3; color: "#dcdde1" }
                    Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: 6; color: "#ffffff" }
                    Text { text: "Light"; color: "#1b1c20"; font.pixelSize: 13; font.bold: true }
                }
                MouseArea { id: lightArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.darkMode = false }
            }
        }

        ColumnLayout {
            spacing: 10
            Layout.topMargin: 8

            Text { text: "Accent color"; color: Theme.textSecondary; font.pixelSize: 13 }

            Row {
                spacing: 14
                Repeater {
                    model: root.accentOptions
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: modelData
                        border.width: root.accentHex === modelData ? 3 : 0
                        border.color: Theme.textPrimary
                        scale: swatchArea.pressed ? Theme.pressScale
                             : (root.accentHex === modelData ? 1.12 : (swatchArea.containsMouse ? Theme.hoverScale : 1.0))

                        Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack } }
                        Behavior on border.width { NumberAnimation { duration: Theme.durationFast } }

                        MouseArea { id: swatchArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.accentHex = modelData }
                    }
                }
            }
        }
    }
}
