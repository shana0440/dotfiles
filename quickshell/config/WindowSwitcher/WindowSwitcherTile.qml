import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme" as Theme

Rectangle {
    id: tile

    required property var window
    required property real thumbHeight
    required property real padding
    required property real headerHeight
    property bool selected: false
    readonly property var entry: DesktopEntries.heuristicLookup(window.lastIpcObject?.class ?? window.wayland?.appId ?? "")

    height: thumbHeight + headerHeight + padding / 2 + 4
    radius: 12
    color: selected ? Theme.Colors.highlight : "transparent"
    border.width: selected ? 2 : 0
    border.color: Theme.Colors.foreground

    Row {
        x: tile.padding / 2
        y: 6
        width: parent.width - tile.padding
        height: tile.headerHeight - 6
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
            text: tile.window.title || tile.entry?.name || ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 12
        }
    }

    Rectangle {
        x: tile.padding / 2
        y: tile.headerHeight
        width: parent.width - tile.padding
        height: tile.thumbHeight
        radius: 6
        color: capture.hasContent ? "transparent" : Theme.Colors.solidSurface

        ScreencopyView {
            id: capture
            readonly property real aspect: sourceSize.width / Math.max(1, sourceSize.height) || 1
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height * aspect)
            height: Math.min(parent.height, parent.width / aspect)
            captureSource: tile.window.wayland
            live: true
            paintCursor: false
        }
    }
}
