import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe

Item {
    id: root
    property var apps: Backend.availableOptionalApps()
    property var selected: ({})

    Component.onCompleted: window.canContinue = true

    function toggle(id) {
        var s = Object.assign({}, root.selected)
        s[id] = !s[id]
        root.selected = s
    }

    function selectedCount() {
        var n = 0
        for (var k in root.selected) if (root.selected[k]) n++
        return n
    }

    // Kick off installs (if any) once the user moves off this page —
    // detached, so it keeps going after the wizard finishes.
    Component.onDestruction: {
        var ids = []
        for (var k in root.selected) if (root.selected[k]) ids.push(k)
        if (ids.length > 0) Backend.installOptionalApps(ids)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 56
        spacing: 16

        Text {
            text: "Optional Apps"
            color: Theme.textPrimary
            font.pixelSize: 26
            font.bold: true
        }
        Text {
            text: "Pick anything you'd like installed automatically. Entirely optional — you can install these later too."
            color: Theme.textSecondary
            font.pixelSize: 13
            Layout.bottomMargin: 4
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: 14
            rowSpacing: 14

            Repeater {
                model: root.apps
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74
                    radius: Theme.radiusCard
                    color: root.selected[modelData.id] ? Qt.rgba(0.353, 0.651, 1, 0.14) : Theme.cardBg
                    border.width: root.selected[modelData.id] ? 2 : 1
                    border.color: root.selected[modelData.id] ? Theme.accent : Theme.divider

                    Behavior on border.color { ColorAnimation { duration: Theme.durationMedium } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text { text: modelData.name; color: Theme.textPrimary; font.pixelSize: 14; font.bold: true }
                            Text {
                                text: modelData.description
                                color: Theme.textSecondary
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            width: 22; height: 22; radius: 6
                            color: root.selected[modelData.id] ? Theme.accent : "transparent"
                            border.width: 1.5
                            border.color: root.selected[modelData.id] ? Theme.accent : Theme.divider

                            Text {
                                anchors.centerIn: parent
                                visible: root.selected[modelData.id] === true
                                text: "✓"
                                color: Theme.accentForeground
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.toggle(modelData.id)
                    }
                }
            }
        }

        Text {
            text: root.selectedCount() === 0 ? "Nothing selected — that's fine too."
                : root.selectedCount() + " app" + (root.selectedCount() === 1 ? "" : "s") + " will install in the background after setup."
            color: Theme.textSecondary
            font.pixelSize: 11
        }
    }
}
