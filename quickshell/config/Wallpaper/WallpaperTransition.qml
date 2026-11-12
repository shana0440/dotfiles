// Pixel-colony wallpaper transitions.
//
// awww remains the wallpaper. While changes run, one window per screen sits
// above it (below windows) and holds one layer per change, newest on top.
// Each layer draws only the cells of its new image that have already arrived
// (wallpaper-colonies maps), so a new change starts at once and spreads over
// whatever is on screen, including changes still running beneath it.
// Hand-over: when a layer has fully covered the screen with its image, awww is
// switched to that image underneath (no transition) and the layer is removed.
// Both show the same pixels, so the removal is invisible.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property var transitions: []        // running changes, oldest first
    property var results: ({})          // token -> final {phase, error}
    property int generation: 0
    property int swappedOrder: 0        // newest change awww already shows
    property var swapQueue: []
    readonly property int duration: 1800
    readonly property int limit: 8      // overlapping changes at once
    property string shaderFile: ""

    function fileUrl(path) { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "" }
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
    function loadShader() {
        // Re-read per change: a rebuild installs the shader under a new path.
        if (Quickshell.env("WALLPAPER_SHADER")) return Quickshell.env("WALLPAPER_SHADER")
        shaderPath.reload()
        return shaderPath.text().trim()
    }
    function find(token) { return transitions.find(t => t.token === token) ?? null }

    function prepare(data) {
        let parsed
        try { parsed = JSON.parse(data) } catch (_) { return "invalid request" }
        if (!parsed.image || !parsed.map || !parsed.outputs?.length) return "invalid request"
        // Where the screen is heading: the newest change, else what awww shows.
        const heading = transitions.length ? [transitions[transitions.length - 1].image]
            : parsed.outputs.map(o => o.displaying?.image ?? "")
        if (heading.every(image => image === parsed.image)) return "same"
        if (transitions.length >= limit) return "busy"
        const shader = loadShader()
        if (!shader) return "no shader"
        // Layers already running keep the shader they started with.
        if (shader !== shaderFile && !transitions.length) shaderFile = shader
        generation++
        const t = transitionComponent.createObject(root, {
            token: String(generation), order: generation, image: parsed.image, map: parsed.map,
            ember: parsed.ember ?? "#ff9a5c", seed: Math.random() * 100
        })
        // Created after the older layers, so it stacks above them.
        t.layers = windows.instances.map(window => layerComponent.createObject(window.contentItem,
            { transition: t, screenName: window.modelData.name }))
        transitions = transitions.concat([t])
        return t.token
    }
    function ready(t, screenName) {
        if (t.phase !== "loading" || t.loaded.includes(screenName)) return
        t.loaded = t.loaded.concat([screenName])
        if (t.loaded.length >= t.layers.length) t.phase = "ready"
    }
    function go(token) {
        const t = find(token)
        if (!t || t.phase !== "ready") return "not ready"
        t.phase = "running"
        t.animation.start()
        return "ok"
    }
    function covered(t) {
        // Fully drawn: switch awww beneath it, one switch at a time, in order.
        t.phase = "swapping"
        swapQueue = swapQueue.concat([t])
        nextSwap()
    }
    function nextSwap() {
        if (swap.running || !swapQueue.length) return
        const t = swapQueue[0]
        swapQueue = swapQueue.slice(1)
        if (t.order < swappedOrder) { t.settle.restart(); return }   // a newer image is already set
        swap.current = t
        swap.command = ["awww", "img", t.image, "--transition-type", "none"]
        swap.running = true
    }
    function finish(t, phase, error) {
        if (!transitions.includes(t)) return
        t.animation.stop(); t.watchdog.stop(); t.settle.stop()
        const done = Object.assign({}, results)
        done[t.token] = { phase: phase, error: error }
        // Keep only recent results; callers poll right after their change.
        for (const key of Object.keys(done)) if (Number(key) < generation - 32) delete done[key]
        results = done
        transitions = transitions.filter(x => x !== t)
        swapQueue = swapQueue.filter(x => x !== t)
        for (const layer of t.layers) layer.destroy()
        t.destroy(1000)     // after its layers, which still bind to it
    }
    function fail(t, reason) { if (t.phase !== "swapping") finish(t, "error", reason) }
    function abort(token) { const t = find(token); if (t) fail(t, "Transition cancelled") }
    function status(token) {
        const t = find(token)
        if (t) return JSON.stringify({ phase: t.phase, error: "" })
        return JSON.stringify(results[token] ?? { phase: "superseded", error: "" })
    }

    FileView {
        id: shaderPath
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/wallpaper/colonies-shader"
        blockLoading: true
    }
    IpcHandler {
        target: "wallpaperTransition"
        function prepare(data: string): string { return root.prepare(data) }
        function go(token: string): string { return root.go(token) }
        function abort(token: string): void { root.abort(token) }
        function status(token: string): string { return root.status(token) }
    }
    Process {
        id: swap
        property var current: null
        onExited: code => {
            const t = current
            current = null
            if (t && root.transitions.includes(t)) {
                if (code === 0) {
                    root.swappedOrder = Math.max(root.swappedOrder, t.order)
                    t.settle.restart()
                } else root.finish(t, "error", "awww could not update the wallpaper")
            }
            root.nextSwap()
        }
    }

    Component {
        id: transitionComponent
        QtObject {
            id: t
            property string token
            property int order
            property string image
            property string map
            property color ember
            property real seed
            property string phase: "loading"   // loading, ready, running, swapping
            property var loaded: []
            property var layers: []
            property real progress: 0
            // Linear time; the shader eases its own area curve.
            property NumberAnimation animation: NumberAnimation {
                target: t; property: "progress"; from: 0; to: 1; duration: root.duration
                easing.type: Easing.Linear
                onFinished: root.covered(t)
            }
            // Give awww a couple of frames to present the image before removing the layer.
            property Timer settle: Timer { interval: 50; onTriggered: root.finish(t, "done", "") }
            property Timer watchdog: Timer {
                interval: root.duration + 5000; running: true
                onTriggered: root.finish(t, "error", "Transition timed out")
            }
        }
    }

    Component {
        id: layerComponent
        Item {
            id: layer
            required property var transition
            required property string screenName
            anchors.fill: parent

            function checkReady() {
                if (!transition) return
                if (newImage.status === Image.Error || colonyMap.status === Image.Error)
                    root.fail(transition, "Could not load transition images")
                else if (newImage.status === Image.Ready && colonyMap.status === Image.Ready)
                    root.ready(transition, screenName)
            }
            Image {
                id: newImage
                visible: false
                source: root.fileUrl(layer.transition.image)
                asynchronous: true
                cache: false
                onStatusChanged: Qt.callLater(layer.checkReady)
            }
            Image {
                id: colonyMap
                visible: false
                source: root.fileUrl(layer.transition.map)
                asynchronous: true
                cache: false
                smooth: false       // packed 16-bit values must not be interpolated
                onStatusChanged: Qt.callLater(layer.checkReady)
            }
            ShaderEffect {
                anchors.fill: parent
                readonly property real progress: layer.transition.progress
                readonly property real cellPx: 5
                readonly property real screenW: width
                readonly property real screenH: height
                readonly property real mapW: Math.max(1, colonyMap.sourceSize.width)
                readonly property real mapH: Math.max(1, colonyMap.sourceSize.height)
                readonly property real seed: layer.transition.seed
                readonly property vector4d newCrop: root.crop(newImage, width, height)
                readonly property color ember: layer.transition.ember
                readonly property var newTexture: newImage
                readonly property var mapTexture: colonyMap
                fragmentShader: root.fileUrl(root.shaderFile)
                onStatusChanged: if (status === ShaderEffect.Error) root.fail(layer.transition, "Colony shader failed")
            }
            Component.onCompleted: Qt.callLater(checkReady)
        }
    }

    Variants {
        id: windows
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.transitions.length > 0
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            // Paint the entire output, including space reserved by the bar.
            // A zero exclusiveZone reserves nothing but still obeys others'
            // reservations, exposing awww above the animation.
            exclusionMode: ExclusionMode.Ignore
            // Same layer as awww (Background) so the bar, which idles on the
            // Bottom layer, stays visible above the transitions. The surface
            // is mapped when changes start, after awww's, so it stacks above.
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-wallpaper-transition"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}
        }
    }
}
