pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string recordingMode: ""
    property real recordingStartedAtMs: 0
    readonly property bool recording: recordingMode.length > 0
    readonly property bool recordingCommandRunning: recordingCommand.running
    readonly property int recordingElapsedSeconds: recording && recordingStartedAtMs > 0
        ? Math.max(0, Math.floor((recordingClock.date.getTime() - recordingStartedAtMs) / 1000)) : 0

    function takeScreenshot(mode) {
        Quickshell.execDetached(["hypr-screenshot", mode])
    }

    function startRecording(mode, outputName) {
        if (!recording && !recordingCommandRunning)
            recordingCommand.exec(["hypr-record", mode, outputName])
    }

    function stopRecording() {
        if (recording && !recordingCommandRunning)
            recordingCommand.exec(["hypr-record", "stop"])
    }

    function refreshRecordingStatus() {
        if (!recordingStatus.running)
            recordingStatus.exec(["hypr-record", "status", "--json"])
    }

    function applyRecordingStatus(data) {
        try {
            const status = JSON.parse(data)
            const mode = status.mode === "full" || status.mode === "region" ? status.mode : ""
            const startedAtMs = Math.max(0, Number(status.startedAtSeconds) || 0) * 1000
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
        id: recordingCommand
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("Recording command failed:", exitCode)
            root.refreshRecordingStatus()
        }
    }

    Process {
        id: recordingStatus
        stdout: SplitParser {
            onRead: data => root.applyRecordingStatus(data)
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
