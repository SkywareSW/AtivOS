import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe

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
            radius: 12
            color: Theme.cardBg

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 18

                Rectangle {
                    width: 48; height: 48; radius: 24
                    color: root.checked && root.connected ? "#2e7d4f" : "#4a3230"
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

                Button {
                    text: "Network Settings"
                    visible: root.checked && !root.connected
                    onClicked: Backend.openNetworkSettings()
                    background: Rectangle { radius: 8; color: Theme.divider; implicitWidth: 150; implicitHeight: 34 }
                    contentItem: Text {
                        text: parent.text
                        color: Theme.textPrimary
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "Check Again"
                    visible: root.checked && !root.connected
                    onClicked: root.recheck()
                    background: Rectangle { radius: 8; color: Theme.accent; implicitWidth: 110; implicitHeight: 34 }
                    contentItem: Text {
                        text: parent.text
                        color: "#0d1117"
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
