import QtQuick
import Quickshell.Hyprland
import "../Theme" as Theme

Rectangle {
    required property int workspaceId

    width: 28
    height: 24
    radius: 4
    color: Hyprland.focusedWorkspace?.id === workspaceId
        ? Theme.Colors.activeWorkspace : Theme.Colors.transparent

    Text {
        anchors.centerIn: parent
        text: workspaceId
        color: Theme.Colors.foreground
        font.pixelSize: 14
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })")
    }
}
