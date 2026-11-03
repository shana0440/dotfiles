import QtQuick
import Quickshell
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    signal closeRequested()

    property string pendingAction: ""
    readonly property bool confirming: pendingAction.length > 0

    implicitWidth: 288
    implicitHeight: confirming ? confirmation.implicitHeight + 24 : actions.implicitHeight + 24
    focus: visible
    Keys.onEscapePressed: root.closeRequested()

    function cancel() {
        pendingAction = ""
    }

    function choose(action) {
        if (action === "lock") {
            closeRequested()
            Quickshell.execDetached(["hyprlock"])
        } else {
            pendingAction = action
        }
    }

    function confirm() {
        const action = pendingAction
        cancel()
        closeRequested()
        if (action === "reboot" || action === "poweroff")
            Quickshell.execDetached(["systemctl", action])
        else if (action === "logout")
            Quickshell.execDetached(["sh", "-c", "if command -v hyprshutdown >/dev/null 2>&1; then hyprshutdown; else hyprctl dispatch 'hl.dsp.exit()'; fi"])
    }

    Column {
        id: actions
        anchors.centerIn: parent
        width: parent.width - 24
        spacing: 4
        visible: !root.confirming

        Repeater {
            model: [
                { label: "Lock", action: "lock" },
                { label: "Log out", action: "logout" },
                { label: "Restart", action: "reboot" },
                { label: "Power off", action: "poweroff" }
            ]

            Rectangle {
                id: actionButton
                required property var modelData

                width: actions.width
                height: 40
                radius: 6
                color: buttonMouse.containsMouse || activeFocus
                    ? Theme.Colors.activeWorkspace : Theme.Colors.transparent
                activeFocusOnTab: true
                Keys.onReturnPressed: root.choose(modelData.action)
                Keys.onSpacePressed: root.choose(modelData.action)
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label

                Components.Icon {
                    id: actionIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    action: modelData.action
                }

                Text {
                    anchors.left: actionIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: Theme.Colors.foreground
                    font.pixelSize: 14
                }

                MouseArea {
                    id: buttonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.choose(modelData.action)
                }

            }
        }
    }

    Column {
        id: confirmation
        anchors.centerIn: parent
        width: parent.width - 24
        spacing: 10
        visible: root.confirming

        Text {
            width: parent.width
            text: root.pendingAction === "reboot" ? "Restart?"
                : root.pendingAction === "poweroff" ? "Power off?" : "Log out?"
            color: Theme.Colors.foreground
            font.pixelSize: 18
            font.bold: true
        }

        Text {
            text: "Unsaved work may be lost."
            color: Theme.Colors.foreground
            opacity: 0.65
            font.pixelSize: 13
        }

        Row {
            spacing: 8

            Repeater {
                model: ["Cancel", "Confirm"]

                Rectangle {
                    required property string modelData

                    width: (confirmation.width - 8) / 2
                    height: 32
                    radius: 6
                    color: confirmMouse.containsMouse ? Theme.Colors.activeWorkspace : Theme.Colors.transparent

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: Theme.Colors.foreground
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData === "Cancel")
                                root.cancel()
                            else
                                root.confirm()
                        }
                    }
                }
            }
        }
    }
}
