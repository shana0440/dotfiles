pragma Singleton
import QtQuick

// Ding's dark palette (ding.yusufcengiz.dev). Color means status only: there is no
// brand accent; emphasis is the foreground itself, and primary controls invert it.
QtObject {
    readonly property color background: "#0c0c0d"
    readonly property color foreground: "#fafafa"
    // Secondary text and quiet indicators.
    readonly property color muted: "#a3a29d"
    // Hairline around floating surfaces: white at 10%.
    readonly property color ring: "#1affffff"
    // Hover and selection fill on a surface: white at 10%.
    readonly property color highlight: "#1affffff"
    // Cards and tiles inside a surface.
    readonly property color surface: "#1c1c1a"
    // Tracks behind meters and progress.
    readonly property color track: "#2c2c2a"
    readonly property color shadow: "#73000000"
    readonly property color transparent: "transparent"

    readonly property color success: "#4ade80"
    readonly property color error: "#f87171"
    readonly property color warning: "#fbbf24"
    readonly property color info: "#60a5fa"

    // Floating panels over the desktop (wallpaper picker, capture toolbar).
    readonly property color panel: "#ed0c0c0d"
    // Shade over the desktop outside a selection.
    readonly property color scrim: "#88000000"
}
