import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme" as Theme
import "../Components" as Components

PanelWindow {
    id: win

    required property var screenInfo
    required property var controller

    readonly property bool shown: controller.opened && Hyprland.focusedMonitor === Hyprland.monitorFor(screenInfo)

    readonly property real padding: 14
    readonly property real spacing: 8
    readonly property real headerHeight: 30
    readonly property real fullThumbHeight: Math.round(Math.min(170, screenInfo.height * 0.16))
    readonly property real availableWidth: screenInfo.width * 0.9 - padding * 2

    function aspectOf(window) {
        const size = window.lastIpcObject?.size
        const aspect = size ? size[0] / Math.max(1, size[1]) : 16 / 10
        return Math.max(0.75, Math.min(1.9, aspect))
    }
    function tileWidth(window, thumb) { return Math.round(thumb * aspectOf(window)) + padding }
    readonly property real fullRowWidth: controller.windows
        .reduce((sum, window) => sum + tileWidth(window, fullThumbHeight), 0)
        + spacing * Math.max(0, controller.windows.length - 1)
    readonly property real scale: Math.max(0.6, Math.min(1, availableWidth / Math.max(1, fullRowWidth)))
    readonly property real thumbHeight: Math.round(fullThumbHeight * scale)
    readonly property var rows: {
        const rows = []
        let row = [], width = 0
        controller.windows.forEach((window, index) => {
            const tile = tileWidth(window, thumbHeight)
            if (row.length && width + spacing + tile > availableWidth) {
                rows.push(row)
                row = []
            }
            width = row.length ? width + spacing + tile : tile
            row.push(index)
        })
        if (row.length) rows.push(row)
        return rows
    }

    screen: screenInfo
    visible: shown
    color: "transparent"
    implicitWidth: panel.width
    implicitHeight: panel.height
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-window-switcher"

    Components.Surface {
        id: panel
        width: tiles.implicitWidth + win.padding * 2
        height: tiles.implicitHeight + win.padding * 2
        radius: 18
        clearness: 0

        Column {
            id: tiles
            x: win.padding
            y: win.padding
            spacing: win.spacing

            Repeater {
                model: win.shown ? win.rows : []

                Row {
                    required property var modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: win.spacing

                    Repeater {
                        model: parent.modelData

                        WindowSwitcherTile {
                            required property int modelData
                            window: win.controller.windows[modelData]
                            width: win.tileWidth(window, win.thumbHeight)
                            selected: window.address === win.controller.selected
                            thumbHeight: win.thumbHeight
                            padding: win.padding
                            headerHeight: win.headerHeight
                            onHovered: win.controller.select(window.address)
                            onClicked: win.controller.choose(window.address)
                        }
                    }
                }
            }
        }
    }
}
