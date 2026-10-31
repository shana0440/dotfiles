pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string recordingMode: ""
    readonly property bool recording: recordingMode.length > 0
    readonly property bool recordingCommandRunning: recordingCommand.running

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
            recordingStatus.exec(["hypr-record", "status"])
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
            onRead: data => {
                const mode = data.trim()
                root.recordingMode = mode === "full" || mode === "region" ? mode : ""
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
