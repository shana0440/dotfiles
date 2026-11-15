import QtQuick
import Quickshell.Hyprland
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    required property int workspaceId
    readonly property var workspace: Hyprland.workspaces.values.find(ws => ws.id === workspaceId) ?? null
    readonly property bool hasWindows: (workspace?.toplevels.values.length ?? 0) > 0
    readonly property bool focused: Hyprland.focusedWorkspace?.id === workspaceId
    readonly property int altKeyDigit: workspaceId % 10

    visible: hasWindows || focused
    width: dot.width + 6
    height: 24
    Accessible.role: Accessible.Button
    Accessible.name: "Workspace " + workspaceId

    Rectangle {
        id: dot
        anchors.centerIn: parent
        width: widthSpring.value
        height: 20
        radius: height / 2
        readonly property real clear: Theme.Colors.clearness
        color: root.focused ? Theme.Colors.foreground
            : Qt.alpha(Theme.Colors.foreground, mouse.containsMouse
                ? 0.28 + (0.7 - 0.28) * clear
                : 0.18 + (0.5 - 0.18) * clear)

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Components.Spring {
            id: widthSpring
            to: root.focused ? 40 : 20
            stiffness: Theme.Motion.morphStiffness
            damping: Theme.Motion.morphDamping
        }

        TextMetrics {
            id: digitInkWithoutLineBox
            text: label.text
            font: label.font
        }
        Text {
            id: label
            x: (dot.width - digitInkWithoutLineBox.tightBoundingRect.width) / 2 - digitInkWithoutLineBox.tightBoundingRect.x
            y: (dot.height - digitInkWithoutLineBox.tightBoundingRect.height) / 2 - digitInkWithoutLineBox.tightBoundingRect.y - baselineOffset
            text: root.altKeyDigit
            color: root.focused ? Theme.Colors.background
                : Theme.Colors.themed(Theme.Colors.foreground, Theme.Colors.background)
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
