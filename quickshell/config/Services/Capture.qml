pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Read-only view of the standalone screen-capture application's recording
// state, plus a stop request. Capturing itself lives in screen-capture/.
Singleton {
    id: root

    property string recordingMode: ""
    property real recordingStartedAtMs: 0
    property bool statusRefreshQueued: false
    readonly property bool recording: recordingMode.length > 0
    readonly property bool recordingCommandRunning: stopCommand.running
    readonly property int recordingElapsedSeconds: recording && recordingStartedAtMs > 0
        ? Math.max(0, Math.floor((clock.date.getTime() - recordingStartedAtMs) / 1000)) : 0

    function stopRecording() {
        if (recording && !stopCommand.running)
            stopCommand.exec(["screen-capture-record", "stop"])
    }

    function refreshStatus() {
        if (statusCommand.running) {
            statusRefreshQueued = true
            return
        }
        statusCommand.exec(["screen-capture-record", "status", "--json"])
    }

    function applyStatus(data) {
        const status = JSON.parse(data)
        const mode = ["full", "region", "window"].includes(status.mode) ? status.mode : ""
        const startedAtMs = Math.max(0, Number(status.startedAtSeconds) || 0) * 1000
        // The completion hook removes session metadata while the service is still stopping.
        if (mode !== recordingMode || startedAtMs > 0)
            recordingStartedAtMs = mode ? startedAtMs : 0
        recordingMode = mode
    }

    // Pushed by screen-capture-record when a recording starts or stops; the
    // timer below remains as a fallback (e.g. a window closing ends a recording).
    IpcHandler {
        target: "screenCapture"
        function changed(): void { root.refreshStatus() }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Process {
        id: stopCommand
        onExited: root.refreshStatus()
    }

    Process {
        id: statusCommand
        stdout: StdioCollector { id: statusOutput }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                try {
                    root.applyStatus(statusOutput.text.trim())
                } catch (error) {
                    console.warn("Unreadable screen-capture status:", error)
                }
            }
            if (root.statusRefreshQueued) {
                root.statusRefreshQueued = false
                root.refreshStatus()
            }
        }
    }

    // Start and Stop are pushed; polling only catches recordings that end on
    // their own (window closed, recorder failure), so it can be slow.
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }
}
