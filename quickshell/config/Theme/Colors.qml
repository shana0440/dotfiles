pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Ding's dark palette (ding.yusufcengiz.dev). Color means status only: there is no
// brand accent; emphasis is the foreground itself, and primary controls invert it.
Singleton {
    id: root

    // "solid" paints the shell's floating surfaces; "transparent" leaves only their
    // content over the wallpaper. The choice is kept in the shell's state directory.
    readonly property string theme: settings.theme === "transparent" ? "transparent" : "solid"
    readonly property bool transparentTheme: theme === "transparent"

    function toggleTheme() {
        settings.theme = transparentTheme ? "solid" : "transparent"
    }

    readonly property color background: "#0c0c0d"
    readonly property color foreground: "#fafafa"
    // Secondary text and quiet indicators.
    readonly property color muted: "#a3a29d"
    // Hairline around floating surfaces: white at 10%.
    readonly property color ring: "#1affffff"
    // Edge of surfaces floating over the desktop (islands, tooltips): white at 24%,
    // so they still read against a black wallpaper.
    readonly property color edge: "#3dffffff"
    // Hover and selection fill on a surface: white at 10%.
    readonly property color highlight: "#1affffff"
    // Cards and tiles inside a surface, and the same under the pointer. Without a
    // surface behind them they turn to a light tint, so no dark block remains.
    readonly property color surface: transparentTheme ? "#14ffffff" : "#1c1c1a"
    readonly property color surfaceHover: transparentTheme ? "#29ffffff" : "#262624"
    // Tracks behind meters and progress.
    readonly property color track: transparentTheme ? "#29ffffff" : "#2c2c2a"
    readonly property color shadow: "#73000000"
    readonly property color transparent: "transparent"

    readonly property color success: "#4ade80"
    readonly property color error: "#f87171"
    readonly property color warning: "#fbbf24"
    readonly property color info: "#60a5fa"

    // A Ding status name to its color; anything else (loading) is the foreground.
    function status(name) {
        return ({ success: success, error: error, warning: warning, info: info })[name] ?? foreground
    }

    // Floating panels over the desktop (wallpaper picker, capture toolbar).
    readonly property color panel: "#ed0c0c0d"
    // Shade over the desktop outside a selection.
    readonly property color scrim: "#88000000"

    // Fill, edge and shadow of the shell's floating surfaces (islands and the
    // dashboard) under the current theme.
    readonly property color surfaceFill: transparentTheme ? transparent : background
    readonly property color surfaceEdge: transparentTheme ? transparent : edge
    readonly property color surfaceShadow: transparentTheme ? transparent : shadow

    // Only this shell writes the file, so it is read once and not watched: reloading
    // on our own write can read the old contents back and undo the change. Loading
    // blocks so the first frame already has the saved theme.
    FileView {
        path: Quickshell.statePath("theme.json")
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property string theme: "solid"
        }
    }
}
