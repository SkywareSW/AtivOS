import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe
import "components"

ApplicationWindow {
    id: window
    width: 840
    height: 560
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: "AtivOS Setup Assistant"

    Component.onCompleted: {
        x = (Screen.width - width) / 2
        y = (Screen.height - height) / 2
        windowOpacity.start()
    }

    property var pages: [
        { source: "pages/WelcomePage.qml" },
        { source: "pages/LanguagePage.qml" },
        { source: "pages/RegionPage.qml" },
        { source: "pages/AppearancePage.qml" },
        { source: "pages/AccountPage.qml" },
        { source: "pages/NetworkPage.qml" },
        { source: "pages/GamingPage.qml" },
        { source: "pages/AppsPage.qml" },
        { source: "pages/PrivacyPage.qml" },
        { source: "pages/AvatarPage.qml" },
        { source: "pages/FinishPage.qml" }
    ]
    property int pageIndex: 0
    property bool canContinue: true

    function goNext() {
        if (pageIndex < pages.length - 1) {
            pageIndex += 1
            canContinue = true
            stack.replace(pages[pageIndex].source)
        } else {
            Backend.finish()
        }
    }

    function goBack() {
        if (pageIndex > 0) {
            pageIndex -= 1
            canContinue = true
            stack.replace(pages[pageIndex].source)
        }
    }

    // ---- gentle fade-in for the whole window on launch -------------------
    opacity: 0
    NumberAnimation {
        id: windowOpacity
        target: window
        property: "opacity"
        from: 0
        to: 1
        duration: 420
        easing.type: Easing.OutCubic
    }

    // ---- soft drop shadow behind the rounded panel --------------------
    // Hand-rolled (no extra Qt module / build dependency needed): a few
    // stacked, progressively larger, near-transparent rounded outlines
    // under the real panel approximate a soft blur falloff.
    Item {
        anchors.fill: parent
        anchors.margins: -20
        z: -1
        Repeater {
            model: 8
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - (7 - index) * 5
                height: parent.height - (7 - index) * 5
                radius: 22 + (parent.width - width) / 2
                color: "transparent"
                border.width: 3
                border.color: Qt.rgba(0, 0, 0, 0.05 - index * 0.004)
            }
        }
    }

    // ---- the rounded, clipped panel that holds everything -------------
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 22
        color: Theme.bg
        clip: true
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)

        // Frameless window has no OS titlebar to drag by, so the top strip
        // (above any page content) doubles as one.
        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 32
            z: 1
            onPressed: window.startSystemMove()
        }

        // ---- page content: fills the entire panel, no bottom bar at all ----
        StackView {
            id: stack
            anchors.fill: parent
            initialItem: pages[0].source

            replaceEnter: Transition {
                ParallelAnimation {
                    PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationSlow; easing.type: Easing.OutCubic }
                    PropertyAnimation { property: "x"; from: 36; to: 0; duration: Theme.durationSlow; easing.type: Easing.OutCubic }
                    PropertyAnimation { property: "scale"; from: 0.985; to: 1; duration: Theme.durationSlow; easing.type: Easing.OutCubic }
                }
            }
            replaceExit: Transition {
                ParallelAnimation {
                    PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationFast }
                    PropertyAnimation { property: "x"; from: 0; to: -28; duration: Theme.durationFast; easing.type: Easing.InCubic }
                }
            }
        }

        // ---- floating back control: a bare chevron, top-left, no button
        //      chrome at all — appears/disappears with a soft fade+slide ----
        Item {
            id: backControl
            width: 40
            height: 40
            x: 20
            y: 20
            z: 2
            visible: opacity > 0.01
            opacity: (window.pageIndex > 0 && window.pageIndex < window.pages.length - 1) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationMedium; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: "‹"
                font.pixelSize: 26
                font.bold: true
                color: backArea.containsMouse ? Theme.textPrimary : Theme.textSecondary
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }
            MouseArea {
                id: backArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: window.goBack()
            }
        }

        // ---- floating step dots: tiny, no background/pill/divider behind
        //      them — just quiet progress feedback sitting on the panel ----
        Row {
            id: dots
            anchors.horizontalCenter: parent.horizontalCenter
            y: panel.height - 28
            z: 2
            spacing: 7
            opacity: window.pageIndex < window.pages.length - 1 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationMedium } }

            Repeater {
                model: window.pages.length
                Rectangle {
                    width: index === window.pageIndex ? 16 : 5
                    height: 5
                    radius: 2.5
                    color: index === window.pageIndex ? Theme.accent : Qt.rgba(1, 1, 1, 0.16)
                    Behavior on width { NumberAnimation { duration: Theme.durationMedium; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
                }
            }
        }

        // ---- floating continue control: the only "chrome" control left,
        //      sitting directly on the panel background — no bar behind it ----
        PillButton {
            id: nextButton
            x: panel.width - width - 24
            y: panel.height - height - 22
            z: 2
            primary: true
            enabled: window.canContinue
            pillWidth: 132
            text: window.pageIndex === window.pages.length - 2 ? "Finish Setup"
                : window.pageIndex === window.pages.length - 1 ? "Get Started"
                : "Continue"
            onClicked: window.goNext()

            opacity: 0
            Component.onCompleted: appear.start()
            NumberAnimation {
                id: appear
                target: nextButton
                property: "opacity"
                to: 1
                duration: Theme.durationSlow
                easing.type: Easing.OutCubic
            }
        }
    }
}
