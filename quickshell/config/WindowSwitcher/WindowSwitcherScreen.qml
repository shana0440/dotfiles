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
    readonly property real fullRowWidth: controller.windows
        .reduce((sum, window) => sum + fullThumbHeight * aspectOf(window) + padding, 0)
        + spacing * Math.max(0, controller.windows.length - 1)
    readonly property real scale: Math.max(0.6, Math.min(1, availableWidth / Math.max(1, fullRowWidth)))
    readonly property real thumbHeight: Math.round(fullThumbHeight * scale)

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
        width: tiles.width + win.padding * 2
        height: tiles.height + win.padding * 2
        radius: 18
        clearness: 0

        Flow {
            id: tiles
            x: win.padding
            y: win.padding
            width: Math.min(win.fullRowWidth * win.scale, win.availableWidth)
            spacing: win.spacing

            Repeater {
                model: win.shown ? win.controller.windows : []

                Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === win.controller.selected
                    readonly property var entry: DesktopEntries.heuristicLookup(modelData.lastIpcObject?.class ?? modelData.wayland?.appId ?? "")

                    width: Math.round(win.thumbHeight * win.aspectOf(modelData)) + win.padding
                    height: win.thumbHeight + win.headerHeight + win.padding / 2 + 4
                    radius: 12
                    color: selected ? Theme.Colors.highlight : "transparent"
                    border.width: selected ? 2 : 0
                    border.color: Theme.Colors.foreground

                    Row {
                        id: header
                        x: win.padding / 2
                        y: 6
                        width: parent.width - win.padding
                        height: win.headerHeight - 6
                        spacing: 8

                        Image {
                            id: icon
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            sourceSize: Qt.size(36, 36)
                            source: Quickshell.iconPath(tile.entry?.icon || "application-x-executable", true)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - icon.width - parent.spacing
                            text: tile.modelData.title || tile.entry?.name || ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.Colors.foreground
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        x: win.padding / 2
                        y: win.headerHeight
                        width: parent.width - win.padding
                        height: win.thumbHeight
                        radius: 6
                        color: capture.hasContent ? "transparent" : Theme.Colors.solidSurface

                        ScreencopyView {
                            id: capture
                            readonly property real aspect: sourceSize.width / Math.max(1, sourceSize.height) || 1
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height * aspect)
                            height: Math.min(parent.height, parent.width / aspect)
                            captureSource: tile.modelData.wayland
                            live: true
                            paintCursor: false
                        }
                    }
                }
            }
        }
    }
}
