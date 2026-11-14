import QtQuick
import Quickshell.Hyprland
import "../Theme" as Theme
import "../Components" as Components

// One workspace as a numbered dot: white and stretched when focused, half-clear
// white when it has windows, so it takes on what lies behind the island. Empty workspaces hide unless focused, so the row lists only what is
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
        // Matches the apps island's icons.
        height: 20
        radius: height / 2
        // White is the shell's emphasis; hover brightens without looking focused.
        // On the black island the others are a faint white chip with white digits;
        // over the wallpaper they are half-clear white with dark digits.
        readonly property bool clear: Theme.Colors.transparentTheme
        color: root.focused ? Theme.Colors.foreground
            : Qt.alpha(Theme.Colors.foreground, clear
                ? (mouse.containsMouse ? 0.7 : 0.5)
                : (mouse.containsMouse ? 0.28 : 0.18))

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Components.Spring {
            id: widthSpring
            to: root.focused ? 40 : 20
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
            // Workspace 10 is Alt+0, so it reads as 0 like its key.
            text: root.workspaceId % 10
            color: root.focused || dot.clear ? Theme.Colors.background : Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 12
            font.features: ({ "tnum": 1 })

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
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
