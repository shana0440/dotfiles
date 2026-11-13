import QtQuick
import Quickshell.Hyprland
import "../Theme" as Theme

Rectangle {
    id: root

    required property int workspaceId
    readonly property var workspace: Hyprland.workspaces.values.find(ws => ws.id === workspaceId) ?? null
    readonly property bool hasWindows: (workspace?.toplevels.values.length ?? 0) > 0

    width: 28
    height: 24
    radius: 4
    color: Hyprland.focusedWorkspace?.id === workspaceId
        ? Theme.Colors.highlight : Theme.Colors.transparent

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        text: workspaceId
        color: Theme.Colors.foreground
        font.pixelSize: 14
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        width: 3
        height: 3
        radius: width / 2
        color: Theme.Colors.muted
        visible: root.hasWindows
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })")
    }
}
