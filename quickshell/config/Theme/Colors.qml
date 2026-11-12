pragma Singleton
import QtQuick

QtObject {
    readonly property color background: "#121212"
    readonly property color foreground: "#ffffff"
    readonly property color accent: "#a78bfa"
    readonly property color activeWorkspace: "#3f3f3f"
    readonly property color transparent: "transparent"
    // Floating panels over the desktop (wallpaper picker, capture toolbar).
    readonly property color panel: "#ed121212"
    // Shade over the desktop outside a selection.
    readonly property color scrim: "#88000000"
    readonly property color error: "#fca5a5"
}
