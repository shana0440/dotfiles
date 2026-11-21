pragma Singleton
import QtQuick

QtObject {
    id: root

    property string theme: "dark"
    readonly property bool transparentTheme: theme === "transparent"

    function toggleTheme() {
        theme = transparentTheme ? "dark" : "transparent"
    }

    property real clearness: transparentTheme ? 1 : 0
    Behavior on clearness {
        NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
    }

    property bool panelHeld: false
    property real panelClearness: transparentTheme && !panelHeld ? 1 : 0
    Behavior on panelClearness {
        NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
    }

    function themed(solid, clear, t) {
        if (t === undefined)
            t = clearness
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
    readonly property color muted: "#a3a29d"
    readonly property color ring: "#1affffff"
    readonly property color edge: "#3dffffff"
    readonly property color highlight: "#1affffff"
    readonly property color surface: themed(solidSurface, tint, panelClearness)
    readonly property color surfaceHover: themed(solidSurfaceHover, strongTint, panelClearness)
    readonly property color track: themed(solidTrack, strongTint, panelClearness)
    readonly property color solidSurface: "#1c1c1a"
    readonly property color solidSurfaceHover: "#262624"
    readonly property color solidTrack: "#2c2c2a"
    readonly property color tint: "#14ffffff"
    readonly property color strongTint: "#29ffffff"
    readonly property color shadow: "#73000000"
    readonly property color transparent: "transparent"

    readonly property color success: "#4ade80"
    readonly property color error: "#f87171"
    readonly property color recording: "#ff493c"
    readonly property color warning: "#fbbf24"
    readonly property color info: "#60a5fa"

    function status(name) {
        return ({ success: success, error: error, warning: warning, info: info })[name] ?? foreground
    }

    readonly property color panel: "#ed0c0c0d"
    readonly property color scrim: "#88000000"

    function surfaceFill(t) { return themed(background, Qt.rgba(1, 1, 1, 0.2), t) }
    function surfaceEdge(t) { return themed(edge, transparent, t) }
    function surfaceShadow(t) { return themed(shadow, transparent, t) }
}
