import QtQuick
import Quickshell.Hyprland
import "../Theme" as Theme
import "../Components" as Components

// One workspace as a numbered dot: white and stretched when focused, grey when it
// has windows. Empty workspaces hide unless focused, so the row lists only what is
// in use. The item is a little wider than the dot to give an easy target.
Item {
    id: root

    required property int workspaceId
    readonly property var workspace: Hyprland.workspaces.values.find(ws => ws.id === workspaceId) ?? null
    readonly property bool hasWindows: (workspace?.toplevels.values.length ?? 0) > 0
    readonly property bool focused: Hyprland.focusedWorkspace?.id === workspaceId

    visible: hasWindows || focused
    width: dot.width + 6
    height: 24
    Accessible.role: Accessible.Button
    Accessible.name: "Workspace " + workspaceId

    Rectangle {
        id: dot
        anchors.centerIn: parent
        width: widthSpring.value
        height: 16
        radius: height / 2
        // White is the shell's emphasis; hover brightens without looking focused.
        color: root.focused ? Theme.Colors.foreground
            : mouse.containsMouse ? Qt.rgba(0.98, 0.98, 0.98, 0.7) : Theme.Colors.muted

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Components.Spring {
            id: widthSpring
            to: root.focused ? 32 : 16
            stiffness: Theme.Motion.morphStiffness
            damping: Theme.Motion.morphDamping
        }

        // Centre the digits' ink, not the line box: the box reserves ascender and
        // descender space that digits do not fill, which pushes them off centre.
        TextMetrics {
            id: ink
            text: label.text
            font: label.font
        }
        Text {
            id: label
            x: (dot.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x
            y: (dot.height - ink.tightBoundingRect.height) / 2 - ink.tightBoundingRect.y - baselineOffset
            text: root.workspaceId
            color: Theme.Colors.background
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: root.workspaceId >= 10 ? 9 : 10
            font.features: ({ "tnum": 1 })
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + root.workspaceId + " })")
    }

    Components.Tooltip {
        text: "Workspace " + root.workspaceId
        shown: mouse.containsMouse
        delay: 400
    }
}
