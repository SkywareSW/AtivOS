import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe

Item {
    id: root
    property var timezones: Backend.availableTimezones()
    property var keyboards: Backend.availableKeyboardLayouts()
    property string selectedTz: Backend.currentTimezone()
    property string selectedKb: Backend.currentKeyboardLayout()
    property string tzFilter: ""

    readonly property var filteredTimezones: tzFilter === "" ? timezones : timezones.filter(function(z) {
        return z.label.toLowerCase().indexOf(tzFilter.toLowerCase()) !== -1
    })

    Component.onCompleted: window.canContinue = true

    // Applied on leaving the page rather than on every click — these are
    // root-gated (pkexec) calls, no need to hammer them on each selection.
    Component.onDestruction: {
        Backend.applyTimezone(selectedTz)
        Backend.applyKeyboardLayout(selectedKb)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 56
        anchors.leftMargin: 56
        anchors.rightMargin: 56
        anchors.bottomMargin: 92
        spacing: 20

        Text {
            text: "Time Zone & Keyboard"
            color: Theme.textPrimary
            font.pixelSize: 26
            font.bold: true
        }
        Text {
            text: "AtivOS picked these based on your install — adjust them if they're not quite right."
            color: Theme.textSecondary
            font.pixelSize: 13
            Layout.bottomMargin: 4
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            // ---- Time zone -------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                Text { text: "Time zone"; color: Theme.textSecondary; font.pixelSize: 12 }

                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: Theme.radiusControl
                    color: Theme.cardBg
                    border.width: tzSearch.activeFocus ? 1 : 0
                    border.color: Theme.accent

                    TextField {
                        id: tzSearch
                        anchors.fill: parent
                        anchors.margins: 1
                        placeholderText: "Search cities…"
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textSecondary
                        font.pixelSize: 12
                        background: Item {}
                        onTextChanged: root.tzFilter = text
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.cardBg
                    radius: Theme.radiusCard

                    ListView {
                        id: tzList
                        anchors.fill: parent
                        anchors.margins: 6
                        clip: true
                        model: root.filteredTimezones
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}

                        delegate: Rectangle {
                            width: tzList.width
                            height: 36
                            radius: Theme.radiusControl
                            color: modelData.id === root.selectedTz ? Theme.accent
                                 : tzArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05)
                                 : "transparent"

                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                elide: Text.ElideRight
                                text: modelData.label
                                color: modelData.id === root.selectedTz ? Theme.accentForeground : Theme.textPrimary
                                font.pixelSize: 12
                                font.bold: modelData.id === root.selectedTz
                            }

                            MouseArea {
                                id: tzArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.selectedTz = modelData.id
                            }
                        }
                    }
                }
            }

            // ---- Keyboard layout --------------------------------------------
            ColumnLayout {
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                spacing: 10

                Text { text: "Keyboard layout"; color: Theme.textSecondary; font.pixelSize: 12 }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.cardBg
                    radius: Theme.radiusCard

                    Flow {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Repeater {
                            model: root.keyboards
                            Rectangle {
                                width: 100; height: 30
                                radius: Theme.radiusControl
                                color: modelData.code === root.selectedKb ? Theme.accent
                                     : kbArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)
                                border.width: modelData.code === root.selectedKb ? 0 : 1
                                border.color: Theme.divider

                                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    elide: Text.ElideRight
                                    width: parent.width - 8
                                    horizontalAlignment: Text.AlignHCenter
                                    color: modelData.code === root.selectedKb ? Theme.accentForeground : Theme.textPrimary
                                    font.pixelSize: 11
                                    font.bold: modelData.code === root.selectedKb
                                }

                                MouseArea {
                                    id: kbArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.selectedKb = modelData.code
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
