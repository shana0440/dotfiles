pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Capture/RegionGeometry.js" as Geometry

Singleton {
    id: root

    property var activeScreenshotPaths: []
    property bool screenshotPending: false
    property var screenshotQueue: []
    property var currentScreenshot: null
    property bool screenshotCommandSaved: false
    readonly property bool takingScreenshot: screenshotPending || screenshotQueue.length > 0
        || (currentScreenshot !== null && !screenshotCommandSaved) || activeScreenshotPaths.length > 0
    signal screenshotSaved(string filePath)

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

    function screenshotStarted(filePath) {
        if (filePath && !activeScreenshotPaths.includes(filePath))
            activeScreenshotPaths = activeScreenshotPaths.concat([filePath])
    }

    function screenshotFinished(filePath) {
        activeScreenshotPaths = activeScreenshotPaths.filter(path => path !== filePath)
    }

    IpcHandler {
        target: "screenshots"
        function started(filePath: string) { root.screenshotStarted(filePath) }
        function finished(filePath: string) { root.screenshotFinished(filePath) }
        function captured(filePath: string) {
            root.screenshotFinished(filePath)
            root.screenshotSaved(filePath)
        }
    }

    function takeScreenshot(mode, outputName) {
        if (mode === "region")
            beginRegionSelection("screenshot", outputName)
        else
            runScreenshot(["hypr-screenshot", mode])
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
            recordingCommand.exec(["hypr-record", mode, outputName])
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
        regionCaptureDelay.kind = selectionKind
        regionCaptureDelay.geometry = Geometry.serialize(selectionRect, screen)
        regionCaptureDelay.outputName = screen.name
        if (selectionKind === "recording")
            startingRecordingGeometry = regionCaptureDelay.geometry
        else
            prepareScreenshot()
        selectionKind = ""
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
                root.runScreenshot(["hypr-screenshot", "region", geometry])
            else if (!root.recording && !root.recordingCommandRunning)
                recordingCommand.exec(["hypr-record", "region", outputName, geometry])
            else
                root.startingRecordingGeometry = ""
        }
    }

    function stopRecording() {
        if (recording && !recordingCommandRunning)
            recordingCommand.exec(["hypr-record", "stop"])
    }

    function refreshRecordingStatus() {
        if (recordingStatus.running) {
            recordingStatusRefreshQueued = true
            return
        }
        recordingStatus.completesRegionStart = confirmRegionStartOnNextStatus
        confirmRegionStartOnNextStatus = false
        recordingStatus.exec(["hypr-record", "status", "--json"])
    }

    function applyRecordingStatus(data) {
        try {
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
        } catch (error) {
            console.warn("Invalid recording status:", error)
        }
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
                if (data.length > 0)
                    root.screenshotCommandSaved = true
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("Screenshot command failed:", exitCode)
        }
    }

    Process {
        id: recordingCommand
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.startingRecordingGeometry = ""
                console.warn("Recording command failed:", exitCode)
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
            if (exitCode === 0)
                root.applyRecordingStatus(recordingStatusOutput.text.trim())
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
