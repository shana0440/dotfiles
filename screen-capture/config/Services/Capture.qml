pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Capture/RegionGeometry.js" as Geometry

Singleton {
    id: root

    property var preview: null
    property bool previewActive: false
    property bool previewRequested: false
    property bool recordingStatusKnown: false
    readonly property bool freezing: freezeCommand.running
    signal previewReady()

    function openPreview() {
        // A restarted UI must not freeze a recording that already runs in systemd.
        if (!recordingStatusKnown) {
            previewRequested = true
            if (!recordingStatus.running)
                refreshRecordingStatus()
            return
        }
        if (freezing || takingScreenshot)
            return
        if (previewActive || recording) {
            previewReady()
            return
        }
        cleanupPreview()
        const screens = Quickshell.screens.map(screen => ({
            name: screen.name, x: screen.x, y: screen.y,
            width: screen.width, height: screen.height
        }))
        freezeCommand.exec(["screen-capture-snapshot", "freeze", JSON.stringify(screens)])
    }

    function cleanupPreview() {
        if (preview !== null) {
            Quickshell.execDetached(["screen-capture-snapshot", "cleanup", preview.directory])
            preview = null
        }
    }

    function dismissPreview() {
        previewActive = false
        // The save process still needs the source frame until it exits.
        if (currentScreenshot === null)
            cleanupPreview()
    }

    function frozenScreenshot(geometry) {
        const directory = preview.directory
        runScreenshot(["screen-capture-snapshot", "save", directory, geometry || ""])
        dismissPreview()
    }

    Process {
        id: freezeCommand
        stdout: StdioCollector { id: freezeOutput }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.errorOccurred("Could not freeze the desktop. Please try again.")
                return
            }
            try {
                root.preview = JSON.parse(freezeOutput.text)
                root.previewActive = !root.recording
                if (root.recording)
                    root.cleanupPreview()
                root.previewReady()
            } catch (error) {
                root.errorOccurred("Could not read the frozen desktop: " + error)
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
    property string startingRecordingGeometry: ""
    readonly property string visibleRecordingGeometry: startingRecordingGeometry || recordingGeometry
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
        if (!filePath || !Number.isInteger(processId) || processId < 0)
            return
        activeScreenshots = activeScreenshots.filter(capture => capture.path !== filePath).concat([{
            path: filePath, processId: processId, expiresAt: Date.now() + 30000
        }])
    }

    function screenshotFinished(filePath) {
        activeScreenshots = activeScreenshots.filter(capture => capture.path !== filePath)
    }

    // PID-less notifications from older installed helpers have a bounded lease.
    // New helpers are tracked for their actual lifetime, including long captures.
    Timer {
        interval: 1000
        running: root.activeScreenshots.length > 0
        repeat: true
        onTriggered: {
            root.activeScreenshots = root.activeScreenshots.filter(capture =>
                capture.processId > 0 || capture.expiresAt > Date.now())
            const processIds = root.activeScreenshots.filter(capture => capture.processId > 0)
                .map(capture => String(capture.processId))
            if (processIds.length > 0 && !screenshotLiveness.running)
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
        function started(filePath: string) { root.screenshotStarted(filePath, 0) }
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
        const mode = status.mode === "full" || status.mode === "region" ? status.mode : ""
        const startedAtMs = Math.max(0, Number(status.startedAtSeconds) || 0) * 1000
        const geometry = Geometry.parse(status.geometry ?? "") ? status.geometry : ""
        if (mode !== recordingMode || geometry.length > 0)
            recordingGeometry = mode === "region" ? geometry : ""
        // The completion hook removes session metadata while the service is still stopping.
        if (mode !== recordingMode || startedAtMs > 0)
            recordingStartedAtMs = mode ? startedAtMs : 0
        recordingMode = mode
    }

    SystemClock {
        id: recordingClock
        precision: SystemClock.Seconds
    }

    Process {
        id: screenshotCommand
        onRunningChanged: {
            // Failed-to-start processes emit this signal without emitting exited.
            if (!running && root.currentScreenshot !== null) {
                root.currentScreenshot = null
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
                root.errorOccurred("Screenshot failed (exit " + exitCode + ").")
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

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshRecordingStatus()
    }
}
