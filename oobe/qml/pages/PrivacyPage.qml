import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe

Item {
    id: root
    property bool telemetryEnabled: false

    Component.onCompleted: {
        window.canContinue = true
        Backend.setTelemetry(telemetryEnabled)
    }
    onTelemetryEnabledChanged: Backend.setTelemetry(telemetryEnabled)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 56
        spacing: 20

        Text {
            text: "Privacy"
            color: Theme.textPrimary
            font.pixelSize: 26
            font.bold: true
        }
        Text {
            text: "AtivOS does not collect any data by default. This is entirely your choice."
            color: Theme.textSecondary
            font.pixelSize: 13
            Layout.bottomMargin: 8
        }

        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.cardBg
            implicitHeight: contentCol.implicitHeight + 32

            ColumnLayout {
                id: contentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 20
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "Share anonymous diagnostics"
                            color: Theme.textPrimary
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Text {
                            text: "Helps prioritize what to fix and improve. Nothing personal is ever included."
                            color: Theme.textSecondary
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.preferredWidth: 480
                        }
                    }

                    Switch {
                        checked: root.telemetryEnabled
                        onToggled: root.telemetryEnabled = checked
                    }
                }
            }
        }

        Text {
            text: "You can change this later in System Settings → AtivOS."
            color: Theme.textSecondary
            font.pixelSize: 11
        }
    }
}
