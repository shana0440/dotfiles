pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Capture/RegionGeometry.js" as Geometry

// Capture state for the capture UI (Capture/) and the bar's recording indicator.
// The work itself is done by the screen-capture-* commands (screen-capture/).
Singleton {
    id: root

    property var preview: null
    property bool previewActive: false
    // Desktop frames come from compositor screencopy in the overlay windows, which
    // is far faster than writing/decoding an image file. `preview` (window list and
    // window frames) arrives separately from the helper a moment later.
    property bool capturing: false
    property var frameScreens: ({})
    property var grabbedFrames: ({})
    property bool saving: false
    property string saveGeometry: ""
    property bool grabAfterManifest: false
    property bool previewRequested: false
    property bool recordingStatusKnown: false
    property bool cleanupPending: false
    property string windowSelectionKind: ""
    property var selectedWindow: null
    property bool windowSelectionLocked: false
    readonly property bool selectingWindow: windowSelectionKind.length > 0
    readonly property bool freezing: freezeCommand.running
    signal previewReady()
    signal grabRequested(string directory)

    function openPreview() {
        // A restarted UI must not freeze a recording that already runs in systemd.
        if (!recordingStatusKnown) {
            previewRequested = true
            if (!recordingStatus.running)
                refreshRecordingStatus()
            return
        }
        if (previewActive || recording) {
            previewReady()
            return
        }
        if (freezing || currentScreenshot !== null) {
            previewRequested = true
            return
        }
        if (takingScreenshot)
            return
        cleanupPreview()
        frameScreens = ({})
        capturing = true
        frameTimeout.restart()
        const screens = Quickshell.screens.map(screen => ({
            name: screen.name, x: screen.x, y: screen.y,
            width: screen.width, height: screen.height
        }))
        freezeCommand.exec(["screen-capture-snapshot", "freeze", JSON.stringify(screens)])
    }

    function frameReady(name) {
        if (!capturing || previewActive)
            return
        const ready = Object.assign({}, frameScreens)
        ready[name] = true
        frameScreens = ready
        if (!Quickshell.screens.every(screen => ready[screen.name]))
            return
        frameTimeout.stop()
        if (recording) {
            dismissPreview()
            return
        }
        previewActive = true
        previewReady()
    }

    function frameFailed(message) {
        frameTimeout.stop()
        grabTimeout.stop()
        const wasSaving = saving
        saving = false
        screenshotPending = false
        dismissPreview()
        errorOccurred(message || (wasSaving ? "Could not save the screenshot." : "Could not capture the desktop. Please try again."))
    }

    Timer {
        id: frameTimeout
        interval: 2500
        onTriggered: root.frameFailed("")
    }

    Timer {
        id: grabTimeout
        interval: 6000
        onTriggered: root.frameFailed("Could not save the screenshot.")
    }

    function cleanupPreview() {
        if (preview === null) {
            if (freezing)
                cleanupPending = true
            return
        }
        if (freezing || currentScreenshot !== null || saving) {
            cleanupPending = true
            return
        }
        Quickshell.execDetached(["screen-capture-snapshot", "cleanup", preview.directory])
        preview = null
        cleanupPending = false
    }

    function beginWindowSelection(kind) {
        windowSelectionKind = kind
        windowSelectionLocked = false
        const windows = preview?.windows ?? []
        selectedWindow = windows.find(window => window.identifier === selectedWindow?.identifier) ?? windows[0] ?? null
    }

    function cancelWindowSelection() {
        windowSelectionKind = ""
        windowSelectionLocked = false
    }

    function captureWindowScreenshot() {
        if (!selectedWindow || !previewActive)
            return
        const identifier = selectedWindow.identifier
        cancelWindowSelection()
        runScreenshot(["screen-capture-snapshot", "save-window", preview.directory, identifier])
        dismissPreview()
    }

    // Keep the dimmed cut-out on screen from the moment Record is pressed: the live
    // outline only exists once the recording and window tracker are running, so the
    // chosen window's rectangle bridges the gap (as range recording does).
    function beginWindowRecording() {
        const window = selectedWindow
        if (!window || recording || recordingCommandRunning || !previewActive)
            return ""
        startingRecordingGeometry = window.x + "," + window.y + " " + window.width + "x" + window.height
        startingWindow = true
        cancelWindowSelection()
        dismissPreview()
        return window.identifier
    }

    function startWindowRecording(identifier) {
        if (!recording && !recordingCommandRunning)
            recordingCommand.exec(["screen-capture-record", "window", identifier])
    }

    function dismissPreview() {
        capturing = false
        previewActive = false
        frameTimeout.stop()
        // The save process still needs the source frame until it exits.
        if (currentScreenshot === null && !saving)
            cleanupPreview()
    }

    // Save from the frozen frames themselves: a separate screen capture here would
    // photograph our own backdrop and toolbar.
    function frozenScreenshot(geometry) {
        if (!previewActive || saving)
            return
        saving = true
        screenshotPending = true
        saveGeometry = geometry || ""
        grabbedFrames = ({})
        grabTimeout.restart()
        if (preview)
            grabRequested(preview.directory)
        else
            grabAfterManifest = true
    }

    function frameGrabbed(name, path, pixelWidth, pixelHeight) {
        if (!saving)
            return
        const grabbed = Object.assign({}, grabbedFrames)
        grabbed[name] = { path: path, pixelWidth: pixelWidth, pixelHeight: pixelHeight }
        grabbedFrames = grabbed
        if (!Quickshell.screens.every(screen => grabbed[screen.name]))
            return
        grabTimeout.stop()
        const frames = Quickshell.screens.map(screen => ({
            name: screen.name, x: screen.x, y: screen.y, width: screen.width, height: screen.height,
            image: grabbed[screen.name].path,
            pixelWidth: grabbed[screen.name].pixelWidth, pixelHeight: grabbed[screen.name].pixelHeight
        }))
        const directory = preview.directory
        saving = false
        runScreenshot(["screen-capture-snapshot", "save-screens", directory, JSON.stringify(frames), saveGeometry])
        dismissPreview()
    }

    Process {
        id: freezeCommand
        property bool delivered: false
        onStarted: delivered = false
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.preview = JSON.parse(data)
                    freezeCommand.delivered = true
                    if (root.windowSelectionKind)
                        root.beginWindowSelection(root.windowSelectionKind)
                    if (root.grabAfterManifest) {
                        root.grabAfterManifest = false
                        root.grabRequested(root.preview.directory)
                    }
                } catch (error) {
                    root.errorOccurred("Could not read the frozen desktop: " + error)
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (!delivered) {
                root.previewRequested = false
                root.errorOccurred("Could not list the windows to capture.")
            }
            if (root.cleanupPending && !root.previewActive)
                root.cleanupPreview()
            if (root.previewRequested) {
                root.previewRequested = false
                Qt.callLater(root.openPreview)
            }
        }
    }

    property var activeScreenshots: []
    property bool screenshotPending: false
    property var screenshotQueue: []
    property var currentScreenshot: null
    property bool screenshotCommandSaved: false
    readonly property bool takingScreenshot: screenshotPending || screenshotQueue.length > 0
        || (currentScreenshot !== null && !screenshotCommandSaved) || activeScreenshots.length > 0
    signal screenshotSaved(string filePath)
    signal errorOccurred(string message)

    property string recordingMode: ""
    property real recordingStartedAtMs: 0
    property string recordingGeometry: ""
    property string recordingWindow: ""
    // Live rectangle of the recorded window, so the outline can follow it.
    property string windowGeometry: ""
    property string startingRecordingGeometry: ""
    // True while the placeholder outline above stands in for a window being started.
    property bool startingWindow: false
    onStartingRecordingGeometryChanged: if (startingRecordingGeometry.length === 0) startingWindow = false
    readonly property string visibleRecordingGeometry: startingRecordingGeometry || recordingGeometry || windowGeometry
    property bool recordingStatusRefreshQueued: false
    property bool confirmRegionStartOnNextStatus: false
    property string selectionKind: ""
    property string selectionScreenName: ""
    property var selectionRect: ({ x: 0, y: 0, width: 0, height: 0 })
    readonly property bool selectingRegion: selectionKind.length > 0
    readonly property bool recording: recordingMode.length > 0
    readonly property bool recordingCommandRunning: recordingCommand.running
    readonly property int recordingElapsedSeconds: recording && recordingStartedAtMs > 0
        ? Math.max(0, Math.floor((recordingClock.date.getTime() - recordingStartedAtMs) / 1000)) : 0

    function screenshotStarted(filePath, processId) {
        if (!filePath || !Number.isInteger(processId) || processId <= 0)
            return
        activeScreenshots = activeScreenshots.filter(capture => capture.path !== filePath).concat([{
            path: filePath, processId: processId
        }])
    }

    function screenshotFinished(filePath) {
        activeScreenshots = activeScreenshots.filter(capture => capture.path !== filePath)
    }

    // A helper that dies without reporting `finished` must not block captures forever.
    Timer {
        interval: 1000
        running: root.activeScreenshots.length > 0
        repeat: true
        onTriggered: {
            const processIds = root.activeScreenshots.map(capture => String(capture.processId))
            if (!screenshotLiveness.running)
                screenshotLiveness.exec(["sh", "-c",
                    'for pid do kill -0 "$pid" 2>/dev/null || printf "%s\\n" "$pid"; done',
                    "screenshot-liveness"].concat(processIds))
        }
    }

    Process {
        id: screenshotLiveness
        stdout: SplitParser {
            onRead: data => {
                const processId = Number(data)
                root.activeScreenshots = root.activeScreenshots.filter(capture => capture.processId !== processId)
            }
        }
    }

    IpcHandler {
        target: "screenshots"
        function startedByProcess(filePath: string, processId: int) { root.screenshotStarted(filePath, processId) }
        function finished(filePath: string) { root.screenshotFinished(filePath) }
        function captured(filePath: string) {
            root.screenshotFinished(filePath)
            root.screenshotSaved(filePath)
        }
    }

    function takeScreenshot(mode, outputName) {
        if (mode === "region")
            beginRegionSelection("screenshot", outputName)
        else if (previewActive)
            frozenScreenshot("")
        else
            runScreenshot(["screen-capture-screenshot", mode])
    }

    function prepareScreenshot() {
        screenshotPending = true
    }

    function runScreenshot(command) {
        screenshotQueue = screenshotQueue.concat([command])
        screenshotPending = false
        startNextScreenshot()
    }

    function startNextScreenshot() {
        if (currentScreenshot !== null || screenshotQueue.length === 0)
            return
        screenshotCommandSaved = false
        currentScreenshot = screenshotQueue[0]
        screenshotQueue = screenshotQueue.slice(1)
        screenshotCommand.exec(currentScreenshot)
    }

    function startRecording(mode, outputName) {
        if (recording || recordingCommandRunning)
            return
        if (mode === "region")
            beginRegionSelection("recording", outputName)
        else
            recordingCommand.exec(["screen-capture-record", mode, outputName])
    }

    function beginRegionSelection(kind, outputName) {
        if (kind !== "screenshot" && kind !== "recording")
            return
        if (kind === "recording" && (recording || recordingCommandRunning || startingRecordingGeometry.length > 0))
            return
        const screen = Quickshell.screens.find(screen => screen.name === outputName) ?? Quickshell.screens[0]
        if (!screen)
            return
        if (regionCaptureDelay.running)
            startingRecordingGeometry = ""
        regionCaptureDelay.stop()
        screenshotPending = false
        selectionRect = { x: 0, y: 0, width: 0, height: 0 }
        selectionScreenName = screen.name
        selectionKind = kind
    }

    function setRegionSelection(screenName, rectangle) {
        if (!selectingRegion)
            return
        const screen = Quickshell.screens.find(screen => screen.name === screenName)
        if (!screen)
            return
        selectionScreenName = screenName
        selectionRect = Geometry.fit(rectangle, screen.width, screen.height)
    }

    function cancelRegionSelection() {
        selectionKind = ""
        if (regionCaptureDelay.running)
            startingRecordingGeometry = ""
        regionCaptureDelay.stop()
        screenshotPending = false
    }

    function confirmRegionSelection() {
        const screen = Quickshell.screens.find(screen => screen.name === selectionScreenName)
        if (!selectingRegion || !screen || selectionRect.width <= 0 || selectionRect.height <= 0)
            return
        selectionRect = Geometry.fit(selectionRect, screen.width, screen.height)
        if (selectionKind === "screenshot" && previewActive) {
            const geometry = Geometry.serialize(selectionRect, screen)
            selectionKind = ""
            frozenScreenshot(geometry)
            return
        }
        regionCaptureDelay.kind = selectionKind
        regionCaptureDelay.geometry = Geometry.serialize(selectionRect, screen)
        regionCaptureDelay.outputName = screen.name
        if (selectionKind === "recording")
            startingRecordingGeometry = regionCaptureDelay.geometry
        else
            prepareScreenshot()
        selectionKind = ""
        dismissPreview()
        regionCaptureDelay.restart()
    }

    // Hide selector controls before capture; recording keeps its click-through outline.
    Timer {
        id: regionCaptureDelay
        property string kind: ""
        property string geometry: ""
        property string outputName: ""
        interval: 80
        onTriggered: {
            if (kind === "screenshot")
                root.runScreenshot(["screen-capture-screenshot", "region", geometry])
            else if (!root.recording && !root.recordingCommandRunning)
                recordingCommand.exec(["screen-capture-record", "region", outputName, geometry])
            else
                root.startingRecordingGeometry = ""
        }
    }

    function stopRecording() {
        if (recording && !recordingCommandRunning)
            recordingCommand.exec(["screen-capture-record", "stop"])
    }

    function refreshRecordingStatus() {
        if (recordingStatus.running) {
            recordingStatusRefreshQueued = true
            return
        }
        recordingStatus.completesRegionStart = confirmRegionStartOnNextStatus
        confirmRegionStartOnNextStatus = false
        recordingStatus.exec(["screen-capture-record", "status", "--json"])
    }

    function applyRecordingStatus(data) {
        const status = JSON.parse(data)
        const mode = ["full", "region", "window"].includes(status.mode) ? status.mode : ""
        const startedAtMs = Math.max(0, Number(status.startedAtSeconds) || 0) * 1000
        const geometry = Geometry.parse(status.geometry ?? "") ? status.geometry : ""
        if (mode !== recordingMode || geometry.length > 0)
            recordingGeometry = mode === "region" ? geometry : ""
        recordingWindow = mode === "window" && /^[0-9a-fA-F]+$/.test(status.window ?? "") ? status.window : ""
        // The completion hook removes session metadata while the service is still stopping.
        if (mode !== recordingMode || startedAtMs > 0)
            recordingStartedAtMs = mode ? startedAtMs : 0
        // Hand over from the placeholder to the live outline without a flash.
        if (mode === "window" && windowGeometry.length === 0 && startingRecordingGeometry.length > 0)
            windowGeometry = startingRecordingGeometry
        recordingMode = mode
    }

    SystemClock {
        id: recordingClock
        precision: SystemClock.Seconds
    }

    Process {
        id: screenshotCommand
        stderr: StdioCollector { id: screenshotErrors }
        onRunningChanged: {
            // Failed-to-start processes emit this signal without emitting exited.
            if (!running && root.currentScreenshot !== null) {
                root.currentScreenshot = null
                // exited may have fired first and deferred cleanup while this
                // screenshot was still current; retry now that it is cleared.
                if (root.cleanupPending && !root.previewActive)
                    root.cleanupPreview()
                Qt.callLater(root.startNextScreenshot)
            }
        }
        stdout: SplitParser {
            onRead: data => {
                if (data.length > 0) {
                    root.screenshotCommandSaved = true
                    if (root.currentScreenshot !== null && root.currentScreenshot[0] === "screen-capture-snapshot")
                        root.screenshotSaved(data)
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (!root.previewActive)
                root.cleanupPreview()
            if (exitCode !== 0)
                root.errorOccurred(screenshotErrors.text.trim() || "Screenshot failed (exit " + exitCode + ").")
            if (root.previewRequested) {
                root.previewRequested = false
                Qt.callLater(root.openPreview)
            }
        }
    }

    Process {
        id: recordingCommand
        property bool startedSuccessfully: false
        onStarted: startedSuccessfully = true
        onRunningChanged: {
            if (running)
                startedSuccessfully = false
            else if (!startedSuccessfully)
                // Failed startup emits runningChanged, but not exited.
                root.startingRecordingGeometry = ""
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.startingRecordingGeometry = ""
                root.errorOccurred("Recording command failed (exit " + exitCode + ").")
            } else if (root.startingRecordingGeometry) {
                root.confirmRegionStartOnNextStatus = true
            }
            root.refreshRecordingStatus()
        }
    }

    function updateWindowGeometry(line) {
        let geometry = ""
        try {
            const [clientsJson, monitorsJson] = line.split("\t")
            // (This QML engine has no Array.flatMap.)
            const visible = []
            for (const monitor of JSON.parse(monitorsJson))
                visible.push(monitor.activeWorkspace?.id, monitor.specialWorkspace?.id)
            const client = JSON.parse(clientsJson).find(client => client.stableId === recordingWindow)
            if (client && client.mapped && !client.hidden && visible.includes(client.workspace?.id))
                geometry = Math.round(client.at[0]) + "," + Math.round(client.at[1]) + " "
                    + Math.round(client.size[0]) + "x" + Math.round(client.size[1])
        } catch (error) {
            // A partial or unavailable reading simply hides the outline for a moment.
        }
        if (geometry !== windowGeometry)
            windowGeometry = geometry
    }

    // Poll Hyprland only while a window recording runs (about 10 Hz).
    Process {
        id: windowTracker
        running: root.recordingMode === "window" && root.recordingWindow.length > 0
        command: ["sh", "-c",
            "while :; do hyprctl -j clients | tr -d '\\n'; printf '\\t'; hyprctl -j monitors | tr -d '\\n'; echo; sleep 0.1; done"]
        stdout: SplitParser {
            onRead: data => root.updateWindowGeometry(data)
        }
        onRunningChanged: if (!running) root.windowGeometry = ""
    }

    Process {
        id: recordingStatus
        property bool completesRegionStart: false
        stdout: StdioCollector { id: recordingStatusOutput }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.applyRecordingStatus(recordingStatusOutput.text.trim())
                root.recordingStatusKnown = true
                if (root.previewRequested) {
                    root.previewRequested = false
                    Qt.callLater(root.openPreview)
                }
            } else if (root.previewRequested) {
                root.previewRequested = false
                root.errorOccurred("Could not check the recording service. Please try again.")
            }
            // Only a status query issued after Start may retire the pending outline.
            if (completesRegionStart)
                root.startingRecordingGeometry = ""
            if (root.recordingStatusRefreshQueued) {
                root.recordingStatusRefreshQueued = false
                root.refreshRecordingStatus()
            }
        }
    }

    // Pushed by screen-capture-record when a recording starts or stops.
    IpcHandler {
        target: "screenCapture"
        function changed(): void { root.refreshRecordingStatus() }
    }

    // Start and Stop are pushed; polling only catches recordings that end on
    // their own (window closed, recorder failure), so it can be slow.
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshRecordingStatus()
    }
}
