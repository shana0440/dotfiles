// Pixel-colony wallpaper transition.
//
// awww remains the wallpaper. For the length of a change this draws a layer
// above it (below windows): colonies of the new image spread over the old one
// in crisp cells, following a precomputed arrival map (wallpaper-colonies).
// Hand-over: fade in over awww while the shader still shows exactly the old
// image, switch awww underneath with no transition, finish on exactly the new
// image, fade out. Every step is invisible because both ends match awww.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property string phase: "idle"
    property string error: ""
    property var request: ({})
    property int generation: 0
    property int swapGeneration: -1
    property var loadedScreens: []
    property real progress: 0
    property real coverage: 0
    property real seed: 0
    property bool swapped: false
    property int duration: 1800
    readonly property bool active: ["loading", "ready", "running", "waiting", "fading"].includes(phase)
    readonly property string shaderFile: Quickshell.env("WALLPAPER_SHADER")
        || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/wallpaper/colonies.frag.qsb"

    function fileUrl(path) { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "" }
    function shown(name) {
        const outputs = request.outputs ?? []
        return (outputs.find(o => o.name === name) ?? outputs[0])?.displaying ?? {}
    }
    function oldImage(name) { return shown(name).image ?? "" }
    // awww reports a solid colour (e.g. before the first wallpaper) instead of
    // an image; the shader then starts from that colour.
    function oldColor(name) {
        const c = shown(name).color
        if (Array.isArray(c)) return Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1)
        // awww prints the colour as an unpadded hex number, e.g. "#0" for black.
        if (typeof c === "string") return "#" + c.replace(/^#|^0x/, "").padStart(6, "0").slice(-6)
        return "black"
    }
    function crop(image, width, height) {
        // awww's default "crop" resize: cover the output, centred.
        if (!image.sourceSize.width || !image.sourceSize.height || !width || !height)
            return Qt.vector4d(0, 0, 1, 1)
        const imageRatio = image.sourceSize.width / image.sourceSize.height
        const screenRatio = width / height
        const sx = Math.min(1, screenRatio / imageRatio)
        const sy = Math.min(1, imageRatio / screenRatio)
        return Qt.vector4d((1 - sx) / 2, (1 - sy) / 2, sx, sy)
    }
    function ready(name) {
        if (phase !== "loading" || loadedScreens.includes(name)) return
        loadedScreens = loadedScreens.concat([name])
        if (loadedScreens.length === windows.instances.length) phase = "ready"
    }
    function prepare(data) {
        if (active) return "busy"
        let parsed
        try { parsed = JSON.parse(data) } catch (_) { return "invalid request" }
        if (!parsed.image || !parsed.map || !parsed.outputs?.length) return "invalid request"
        request = parsed
        error = ""
        generation++
        progress = 0
        coverage = 0
        seed = Math.random() * 100
        swapped = false
        loadedScreens = []
        phase = "loading"
        watchdog.restart()
        return String(generation)
    }
    function go(token) {
        if (token !== String(generation) || phase !== "ready") return "not ready"
        phase = "running"
        animation.restart()
        cover.restart()
        return "ok"
    }
    function fail(reason) {
        error = reason
        animation.stop(); cover.stop(); uncover.stop(); settle.stop(); watchdog.stop()
        phase = "error"
        coverage = 0
    }
    function finishIfReady() {
        if (animation.running) return
        if (!swapped) { phase = "waiting"; return }
        phase = "fading"
        uncover.restart()
    }
    function abort(token) {
        if (token !== String(generation)) return
        swapGeneration = -1
        swap.running = false
        fail("Transition cancelled")
    }

    IpcHandler {
        target: "wallpaperTransition"
        function prepare(data: string): string { return root.prepare(data) }
        function go(token: string): string { return root.go(token) }
        function abort(token: string): void { root.abort(token) }
        function status(token: string): string {
            return JSON.stringify({phase: token === String(root.generation) ? root.phase : "superseded", error: root.error})
        }
    }
    // Linear time; the shader eases its own area curve.
    NumberAnimation {
        id: animation
        target: root; property: "progress"; from: 0; to: 1; duration: root.duration
        easing.type: Easing.Linear
        onFinished: root.finishIfReady()
    }
    NumberAnimation {
        id: cover
        target: root; property: "coverage"; from: 0; to: 1; duration: 90
        onFinished: {
            if (!root.active) return
            root.swapGeneration = root.generation
            swap.command = ["awww", "img", root.request.image, "--transition-type", "none"]
            swap.running = true
        }
    }
    Process {
        id: swap
        onExited: code => {
            if (root.swapGeneration !== root.generation) return
            if (code !== 0) { root.fail("awww could not update the wallpaper"); return }
            settle.restart()
        }
    }
    // Give awww a couple of frames to present the new image before uncovering.
    Timer { id: settle; interval: 50; onTriggered: { root.swapped = true; root.finishIfReady() } }
    NumberAnimation {
        id: uncover
        target: root; property: "coverage"; from: 1; to: 0; duration: 100
        onFinished: { watchdog.stop(); root.phase = "done" }
    }
    Timer { id: watchdog; interval: root.duration + 5000; onTriggered: root.fail("Transition timed out") }

    Variants {
        id: windows
        model: Quickshell.screens
        PanelWindow {
            id: window
            required property var modelData
            readonly property bool fromColor: root.active && !root.oldImage(modelData.name)
            screen: modelData
            visible: root.active
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            // Paint the entire output, including space reserved by the bar.
            // A zero exclusiveZone reserves nothing but still obeys others'
            // reservations, exposing the new awww image above the animation.
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell-wallpaper-transition"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            function checkReady() {
                if ((!fromColor && oldImage.status === Image.Error) || newImage.status === Image.Error
                        || colonyMap.status === Image.Error) {
                    if (root.active) root.fail("Could not load transition images")
                    return
                }
                if ((fromColor || oldImage.status === Image.Ready) && newImage.status === Image.Ready
                        && colonyMap.status === Image.Ready)
                    root.ready(window.modelData.name)
            }
            Connections {
                target: root
                function onGenerationChanged() { Qt.callLater(window.checkReady) }
            }
            Image {
                id: oldImage
                visible: false
                source: root.active && !window.fromColor ? root.fileUrl(root.oldImage(window.modelData.name)) : ""
                asynchronous: true
                cache: false
                onStatusChanged: Qt.callLater(window.checkReady)
            }
            Image {
                id: newImage
                visible: false
                source: root.active ? root.fileUrl(root.request.image) : ""
                asynchronous: true
                cache: false
                onStatusChanged: Qt.callLater(window.checkReady)
            }
            Image {
                id: colonyMap
                visible: false
                source: root.active ? root.fileUrl(root.request.map) : ""
                asynchronous: true
                cache: false
                smooth: false       // packed 16-bit values must not be interpolated
                onStatusChanged: Qt.callLater(window.checkReady)
            }
            ShaderEffect {
                anchors.fill: parent
                opacity: root.coverage
                readonly property real progress: root.progress
                readonly property real cellPx: 5
                readonly property real screenW: width
                readonly property real screenH: height
                readonly property real mapW: Math.max(1, colonyMap.sourceSize.width)
                readonly property real mapH: Math.max(1, colonyMap.sourceSize.height)
                readonly property real seed: root.seed
                readonly property real fromColor: window.fromColor ? 1 : 0
                readonly property vector4d oldCrop: root.crop(oldImage, width, height)
                readonly property vector4d newCrop: root.crop(newImage, width, height)
                readonly property color ember: root.request.ember ?? "#ff9a5c"
                readonly property color oldColor: root.oldColor(window.modelData.name)
                // A sampler needs a texture even when starting from a colour.
                readonly property var oldTexture: window.fromColor ? newImage : oldImage
                readonly property var newTexture: newImage
                readonly property var mapTexture: colonyMap
                fragmentShader: root.fileUrl(root.shaderFile)
                onStatusChanged: if (status === ShaderEffect.Error && root.active) root.fail("Colony shader failed")
            }
        }
    }
}
