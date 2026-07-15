import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe
import "../components"

Item {
    id: root
    property bool connected: false
    property bool checked: false

    Component.onCompleted: {
        window.canContinue = true // network is never a hard blocker
        recheck()
    }

    function recheck() {
        checked = false
        connected = Backend.checkNetwork()
        checked = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 56
        spacing: 20

        Text {
            text: "Network"
            color: Theme.textPrimary
            font.pixelSize: 26
            font.bold: true
        }
        Text {
            text: "AtivOS works best online — updates and app installs both need a connection."
            color: Theme.textSecondary
            font.pixelSize: 13
            Layout.bottomMargin: 8
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            radius: Theme.radiusCard
            color: Theme.cardBg

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 18

                Rectangle {
                    id: statusCircle
                    width: 48; height: 48; radius: 24
                    color: !root.checked ? Theme.cardBg : (root.connected ? "#2e7d4f" : "#4a3230")

                    Behavior on color { ColorAnimation { duration: Theme.durationMedium } }

                    SequentialAnimation on opacity {
                        running: !root.checked
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.55; duration: 500; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.checked ? (root.connected ? "✓" : "!") : "…"
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                    }
                }

                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true
                    Text {
                        text: !root.checked ? "Checking connection…"
                            : root.connected ? "You're connected"
                            : "No internet connection"
                        color: Theme.textPrimary
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Text {
                        text: !root.checked ? "This will just take a moment."
                            : root.connected ? "Everything looks good."
                            : "Connect to Wi-Fi or plug in ethernet, then check again."
                        color: Theme.textSecondary
                        font.pixelSize: 12
                    }
                }

                PillButton {
                    text: "Network Settings"
                    flatStyle: true
                    pillHeight: 34
                    pillWidth: 150
                    visible: root.checked && !root.connected
                    onClicked: Backend.openNetworkSettings()
                }

                PillButton {
                    text: "Check Again"
                    primary: true
                    pillHeight: 34
                    pillWidth: 110
                    visible: root.checked && !root.connected
                    onClicked: root.recheck()
                }
            }
        }
    }
}
