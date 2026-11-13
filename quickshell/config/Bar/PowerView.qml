import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme" as Theme
import "../Components" as Components

// The dashboard's power tab: lock and log out, then restart and power off.
// Everything but lock asks for a second click, so one stray click loses nothing.
Item {
    id: root

    property bool active: false
    // The tiles grow to fill this, the height the tab rail already gives the dashboard.
    property real fillHeight: 0
    signal closeRequested()

    // The action waiting for its second click, or "".
    property string armedAction: ""
    readonly property string user: Quickshell.env("USER") ?? ""

    implicitWidth: 480
    implicitHeight: content.implicitHeight + 40

    onActiveChanged: armedAction = ""

    function choose(action) {
        if (action === "lock") {
            run(action)
            return
        }
        if (armedAction !== action) {
            armedAction = action
            disarm.restart()
            return
        }
        run(action)
    }

    function run(action) {
        armedAction = ""
        closeRequested()
        if (action === "lock")
            Quickshell.execDetached(["hyprlock"])
        else if (action === "reboot" || action === "poweroff")
            Quickshell.execDetached(["systemctl", action])
        else if (action === "logout")
            Quickshell.execDetached(["sh", "-c", "if command -v hyprshutdown >/dev/null 2>&1; then hyprshutdown; else hyprctl dispatch 'hl.dsp.exit()'; fi"])
    }

    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armedAction = ""
    }

    FileView {
        id: hostname
        path: "/proc/sys/kernel/hostname"
        blockLoading: true
    }

    component Tile: Rectangle {
        id: tile
        property string action: ""
        property string label: ""
        property string armedLabel: ""
        readonly property bool armed: root.armedAction === action

        width: (content.width - grid.columnSpacing) / 2
        height: Math.max(112, (root.fillHeight - 40 - header.height - content.spacing - grid.rowSpacing) / 2)
        radius: 12
        color: armed ? Theme.Colors.foreground
            : tileMouse.containsMouse || activeFocus ? Qt.lighter(Theme.Colors.surface, 1.35) : Theme.Colors.surface
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: armed ? armedLabel : label
        Keys.onReturnPressed: root.choose(action)
        Keys.onSpacePressed: root.choose(action)

        Components.Icon {
            x: 20
            y: 20
            width: 32
            height: 32
            action: tile.action
            iconColor: tile.armed ? Theme.Colors.background : Theme.Colors.foreground
        }
        Column {
            x: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: parent.width - 40
            spacing: 4

            Text {
                width: parent.width
                text: tile.armed ? tile.armedLabel : tile.label
                elide: Text.ElideRight
                color: tile.armed ? Theme.Colors.background : Theme.Colors.foreground
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 16
            }
            Text {
                width: parent.width
                visible: tile.armed
                text: "Unsaved work may be lost"
                elide: Text.ElideRight
                color: Theme.Colors.background
                opacity: 0.7
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 12
            }
        }
        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.choose(tile.action)
        }
    }

    Column {
        id: content
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 16

        Item {
            id: header
            width: parent.width
            height: 32

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Power"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    text: root.user + (hostname.text().trim() ? " on " + hostname.text().trim() : "")
                    textFormat: Text.PlainText
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }
            }
        }

        Grid {
            id: grid
            columns: 2
            columnSpacing: 12
            rowSpacing: 12

            Tile {
                action: "lock"
                label: "Lock"
            }
            Tile {
                action: "logout"
                label: "Log out"
                armedLabel: "Click again to log out"
            }
            Tile {
                action: "reboot"
                label: "Restart"
                armedLabel: "Click again to restart"
            }
            Tile {
                action: "poweroff"
                label: "Power off"
                armedLabel: "Click again to power off"
            }
        }
    }
}
