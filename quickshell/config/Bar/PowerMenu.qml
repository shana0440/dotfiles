import QtQuick
import Quickshell
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    signal closeRequested()

    property string pendingAction: ""
    readonly property bool confirming: pendingAction.length > 0

    implicitWidth: confirming ? 288 : actions.implicitWidth + 12
    implicitHeight: confirming ? confirmation.implicitHeight + 24 : 32
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

    Row {
        id: actions
        anchors.centerIn: parent
        spacing: 4
        visible: !root.confirming

        Repeater {
            model: [
                { label: "Lock", action: "lock" },
                { label: "Log out", action: "logout" },
                { label: "Restart", action: "reboot" },
                { label: "Shut down", action: "poweroff" }
            ]

            Rectangle {
                id: actionButton
                required property var modelData

                width: 36
                height: 28
                radius: 6
                color: buttonMouse.containsMouse || activeFocus
                    ? Theme.Colors.activeWorkspace : Theme.Colors.transparent
                activeFocusOnTab: true
                Keys.onReturnPressed: root.choose(modelData.action)
                Keys.onSpacePressed: root.choose(modelData.action)
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label

                Components.Icon {
                    anchors.centerIn: parent
                    action: modelData.action
                }

                MouseArea {
                    id: buttonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.choose(modelData.action)
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height + 10
                    width: label.implicitWidth + 16
                    height: 24
                    radius: 6
                    color: Theme.Colors.background
                    visible: buttonMouse.containsMouse || actionButton.activeFocus

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.label
                        color: Theme.Colors.foreground
                        font.pixelSize: 12
                    }
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
                : root.pendingAction === "poweroff" ? "Shut down?" : "Log out?"
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
