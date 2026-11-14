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

    // 0 in the solid theme, 1 in the transparent one, and in between while the
    // theme changes, so every themed color fades instead of switching. The easing
    // is symmetric so both directions take the same time to the eye: an ease-out
    // leaves a faint veil lingering on the way to transparent only.
    property real clearness: transparentTheme ? 1 : 0
    Behavior on clearness {
        NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
    }

    // A themed color at the current clearness. Premultiplied, so a dark fill fading
    // out does not pass through a light grey on the way.
    function themed(solid, clear) {
        const t = clearness
        const s = 1 - t
        const a = solid.a * s + clear.a * t
        if (a <= 0)
            return Qt.rgba(0, 0, 0, 0)
        return Qt.rgba((solid.r * solid.a * s + clear.r * clear.a * t) / a,
            (solid.g * solid.a * s + clear.g * clear.a * t) / a,
            (solid.b * solid.a * s + clear.b * clear.a * t) / a, a)
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
    readonly property color surface: themed(solidSurface, tint)
    readonly property color surfaceHover: themed(solidSurfaceHover, strongTint)
    // Tracks behind meters and progress.
    readonly property color track: themed(solidTrack, strongTint)
    readonly property color solidSurface: "#1c1c1a"
    readonly property color solidSurfaceHover: "#262624"
    readonly property color solidTrack: "#2c2c2a"
    // White at 8% and 16%: cards and tracks over the wallpaper.
    readonly property color tint: "#14ffffff"
    readonly property color strongTint: "#29ffffff"
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
    readonly property color surfaceFill: themed(background, transparent)
    readonly property color surfaceEdge: themed(edge, transparent)
    readonly property color surfaceShadow: themed(shadow, transparent)

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
