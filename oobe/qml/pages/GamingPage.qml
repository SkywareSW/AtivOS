import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe

Item {
    id: root
    property bool gameMode: Backend.gameModeEnabled()
    property bool mangoHud: Backend.mangoHudEnabled()
    property string profile: Backend.performanceProfile()

    property var profiles: [
        { id: "responsive", name: "Responsive", desc: "Prioritizes whatever's in focus. Best for gaming." },
        { id: "balanced", name: "Balanced", desc: "A solid all-around default for everyday use." },
        { id: "battery", name: "Battery Saver", desc: "Trades some responsiveness for longer battery life." }
    ]

    Component.onCompleted: window.canContinue = true
    onGameModeChanged: Backend.setGameMode(gameMode)
    onMangoHudChanged: Backend.setMangoHudEnabled(mangoHud)
    onProfileChanged: Backend.applyPerformanceProfile(profile)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 56
        spacing: 18

        Text {
            text: "Gaming & Performance"
            color: Theme.textPrimary
            font.pixelSize: 26
            font.bold: true
        }
        Text {
            text: "AtivOS ships tuned for gaming out of the box. Adjust it here if you'd rather it didn't."
            color: Theme.textSecondary
            font.pixelSize: 13
            Layout.bottomMargin: 4
        }

        // ---- Game Mode toggle ------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            radius: Theme.radiusCard
            color: Theme.cardBg
            implicitHeight: gmCol.implicitHeight + 28

            ColumnLayout {
                id: gmCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 18
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Game Mode"; color: Theme.textPrimary; font.pixelSize: 14; font.bold: true }
                        Text {
                            text: "Boosts CPU/GPU priority and inhibits the screensaver automatically while a game runs."
                            color: Theme.textSecondary
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.preferredWidth: 460
                        }
                    }
                    Switch {
                        checked: root.gameMode
                        onToggled: root.gameMode = checked
                    }
                }
            }
        }

        // ---- MangoHud toggle --------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            radius: Theme.radiusCard
            color: Theme.cardBg
            implicitHeight: mhCol.implicitHeight + 28

            ColumnLayout {
                id: mhCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 18
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Performance overlay by default"; color: Theme.textPrimary; font.pixelSize: 14; font.bold: true }
                        Text {
                            text: "Shows FPS, temps, and RAM/VRAM usage (MangoHud) automatically. Toggle anytime with Shift+F12."
                            color: Theme.textSecondary
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.preferredWidth: 460
                        }
                    }
                    Switch {
                        checked: root.mangoHud
                        onToggled: root.mangoHud = checked
                    }
                }
            }
        }

        // ---- Performance profile -----------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10

            Text { text: "Scheduler profile"; color: Theme.textSecondary; font.pixelSize: 12 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: root.profiles
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        radius: Theme.radiusCard
                        color: root.profile === modelData.id ? Qt.rgba(0.353, 0.651, 1, 0.14) : Theme.cardBg
                        border.width: root.profile === modelData.id ? 2 : 1
                        border.color: root.profile === modelData.id ? Theme.accent : Theme.divider
                        scale: profArea.pressed ? Theme.pressScale : (profArea.containsMouse ? Theme.hoverScale : 1.0)

                        Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationMedium } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 4
                            Text { text: modelData.name; color: Theme.textPrimary; font.pixelSize: 13; font.bold: true }
                            Text {
                                text: modelData.desc
                                color: Theme.textSecondary
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: profArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.profile = modelData.id
                        }
                    }
                }
            }
        }
    }
}
