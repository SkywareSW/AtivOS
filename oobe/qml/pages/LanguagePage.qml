import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe

Item {
    id: root
    property var languages: Backend.availableLanguages()
    property int selectedIndex: 0

    Component.onCompleted: window.canContinue = true

    function apply() {
        if (languages.length > 0) {
            Backend.applyLanguage(languages[selectedIndex].code)
        }
    }

    // Apply immediately as the user picks a language.
    onSelectedIndexChanged: apply()
    Component.onDestruction: apply()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 56
        spacing: 20

        Text {
            text: "Language & Region"
            color: Theme.textPrimary
            font.pixelSize: 26
            font.bold: true
        }
        Text {
            text: "Choose the language AtivOS will use for menus and dialogs in your account."
            color: Theme.textSecondary
            font.pixelSize: 13
            Layout.bottomMargin: 8
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.cardBg
            radius: 10

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                model: root.languages
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: listView.width
                    height: 44
                    radius: 8
                    color: index === root.selectedIndex ? Theme.accent : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: index === root.selectedIndex ? "#0d1117" : Theme.textPrimary
                        font.pixelSize: 14
                        font.bold: index === root.selectedIndex
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.selectedIndex = index
                    }
                }
            }
        }
    }
}
