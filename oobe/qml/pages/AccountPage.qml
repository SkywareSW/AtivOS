import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.ativos.oobe
import "../components"

Item {
    id: root

    property string fullName: Backend.currentFullName()
    property string hostname: Backend.currentHostname()
    property bool renamingUser: false
    property string newUsername: ""
    property bool usernameAvailable: true
    property bool usernameChecked: false
    property string renameStatus: ""

    property bool changingPassword: false
    property string newPassword: ""
    property string confirmPassword: ""
    property string passwordStatus: ""

    Component.onCompleted: window.canContinue = true

    function checkUsername() {
        if (newUsername === "" || newUsername === Backend.currentUser()) {
            usernameChecked = false
            return
        }
        usernameAvailable = Backend.isUsernameAvailable(newUsername)
        usernameChecked = true
    }

    ScrollView {
        anchors.fill: parent
        anchors.topMargin: 56
        anchors.leftMargin: 56
        anchors.rightMargin: 40
        anchors.bottomMargin: 92
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 16

            Text {
                text: "Your Account"
                color: Theme.textPrimary
                font.pixelSize: 26
                font.bold: true
            }
            Text {
                text: "Confirm how you're identified on this machine. All of this can be changed later too."
                color: Theme.textSecondary
                font.pixelSize: 13
                Layout.bottomMargin: 4
            }

            // ---- Full name ------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 78
                radius: Theme.radiusCard
                color: Theme.cardBg

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6
                    Text { text: "Full name"; color: Theme.textSecondary; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: Theme.radiusControl
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: fullNameField.activeFocus ? 1 : 0
                        border.color: Theme.accent

                        TextField {
                            id: fullNameField
                            anchors.fill: parent
                            anchors.margins: 1
                            text: root.fullName
                            color: Theme.textPrimary
                            font.pixelSize: 13
                            background: Item {}
                            onEditingFinished: {
                                root.fullName = text
                                Backend.setFullName(text)
                            }
                        }
                    }
                }
            }

            // ---- Username ----------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: usernameCol.implicitHeight + 32
                radius: Theme.radiusCard
                color: Theme.cardBg

                ColumnLayout {
                    id: usernameCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text { text: "Username"; color: Theme.textSecondary; font.pixelSize: 11 }
                            Text { text: Backend.currentUser(); color: Theme.textPrimary; font.pixelSize: 14; font.bold: true }
                        }

                        PillButton {
                            text: root.renamingUser ? "Cancel" : "Rename…"
                            flatStyle: true
                            pillHeight: 30
                            pillWidth: 96
                            onClicked: {
                                root.renamingUser = !root.renamingUser
                                root.newUsername = ""
                                root.usernameChecked = false
                                root.renameStatus = ""
                            }
                        }
                    }

                    ColumnLayout {
                        visible: root.renamingUser
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            radius: Theme.radiusControl
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: !root.usernameChecked ? Theme.divider
                                        : root.usernameAvailable ? Theme.success : Theme.danger

                            TextField {
                                id: newUserField
                                anchors.fill: parent
                                anchors.margins: 1
                                placeholderText: "new-username"
                                placeholderTextColor: Theme.textSecondary
                                color: Theme.textPrimary
                                font.pixelSize: 13
                                background: Item {}
                                onTextChanged: {
                                    root.newUsername = text.toLowerCase()
                                    root.checkUsername()
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.pixelSize: 11
                            text: !root.usernameChecked ? "lowercase letters, numbers, - and _ only"
                                : root.usernameAvailable ? "Available. You'll need to log out and back in afterward."
                                : "That username is already taken."
                            color: !root.usernameChecked ? Theme.textSecondary
                                : root.usernameAvailable ? Theme.success : Theme.danger
                        }

                        PillButton {
                            text: "Confirm Rename"
                            primary: true
                            pillHeight: 32
                            pillWidth: 150
                            enabled: root.usernameChecked && root.usernameAvailable
                            onClicked: {
                                var ok = Backend.renameUsername(root.newUsername)
                                root.renameStatus = ok ? "Renamed — the change finishes on next login."
                                                        : "Couldn't rename right now."
                                root.renamingUser = false
                            }
                        }
                    }

                    Text {
                        visible: root.renameStatus !== ""
                        text: root.renameStatus
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                }
            }

            // ---- Computer name ----------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 78
                radius: Theme.radiusCard
                color: Theme.cardBg

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6
                    Text { text: "Computer name"; color: Theme.textSecondary; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: Theme.radiusControl
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: hostField.activeFocus ? 1 : 0
                        border.color: Theme.accent

                        TextField {
                            id: hostField
                            anchors.fill: parent
                            anchors.margins: 1
                            text: root.hostname
                            color: Theme.textPrimary
                            font.pixelSize: 13
                            background: Item {}
                            onEditingFinished: {
                                root.hostname = text
                                Backend.setHostname(text)
                            }
                        }
                    }
                }
            }

            // ---- Password -------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: passwordCol.implicitHeight + 32
                radius: Theme.radiusCard
                color: Theme.cardBg
                Layout.bottomMargin: 8

                ColumnLayout {
                    id: passwordCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text { text: "Password"; color: Theme.textSecondary; font.pixelSize: 11 }
                            Text { text: "••••••••"; color: Theme.textPrimary; font.pixelSize: 14; font.bold: true }
                        }
                        PillButton {
                            text: root.changingPassword ? "Cancel" : "Change…"
                            flatStyle: true
                            pillHeight: 30
                            pillWidth: 96
                            onClicked: {
                                root.changingPassword = !root.changingPassword
                                root.newPassword = ""
                                root.confirmPassword = ""
                                root.passwordStatus = ""
                            }
                        }
                    }

                    ColumnLayout {
                        visible: root.changingPassword
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            radius: Theme.radiusControl
                            color: Qt.rgba(1, 1, 1, 0.04)
                            TextField {
                                anchors.fill: parent
                                anchors.margins: 1
                                placeholderText: "New password"
                                placeholderTextColor: Theme.textSecondary
                                echoMode: TextInput.Password
                                color: Theme.textPrimary
                                font.pixelSize: 13
                                background: Item {}
                                onTextChanged: root.newPassword = text
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            radius: Theme.radiusControl
                            color: Qt.rgba(1, 1, 1, 0.04)
                            TextField {
                                anchors.fill: parent
                                anchors.margins: 1
                                placeholderText: "Confirm password"
                                placeholderTextColor: Theme.textSecondary
                                echoMode: TextInput.Password
                                color: Theme.textPrimary
                                font.pixelSize: 13
                                background: Item {}
                                onTextChanged: root.confirmPassword = text
                            }
                        }

                        Text {
                            visible: root.newPassword !== "" || root.confirmPassword !== ""
                            text: root.newPassword.length > 0 && root.newPassword.length < 8 ? "At least 8 characters recommended."
                                : (root.confirmPassword !== "" && root.newPassword !== root.confirmPassword) ? "Passwords don't match."
                                : "Looks good."
                            font.pixelSize: 11
                            color: (root.confirmPassword !== "" && root.newPassword === root.confirmPassword && root.newPassword.length >= 8)
                                ? Theme.success : Theme.warning
                        }

                        PillButton {
                            text: "Update Password"
                            primary: true
                            pillHeight: 32
                            pillWidth: 160
                            enabled: root.newPassword.length >= 8 && root.newPassword === root.confirmPassword
                            onClicked: {
                                var ok = Backend.setPassword(root.newPassword)
                                root.passwordStatus = ok ? "Password updated." : "Couldn't update the password."
                                root.changingPassword = false
                            }
                        }
                    }

                    Text {
                        visible: root.passwordStatus !== ""
                        text: root.passwordStatus
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
