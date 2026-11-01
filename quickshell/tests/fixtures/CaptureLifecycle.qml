import QtQuick
import Quickshell
import "Services" as Services

ShellRoot {
    id: root
    property int stage: 0
    property bool done: false
    readonly property bool regionVisible: Services.Capture.selectingRegion
        || Services.Capture.startingRecordingGeometry.length > 0
        || (Services.Capture.recordingMode === "region" && Services.Capture.recordingGeometry.length > 0)

    function check(condition, message) {
        if (!condition) {
            console.error("CAPTURE_TEST_FAIL: " + message)
            done = true
        }
    }

    function selectRecording() {
        Services.Capture.beginRegionSelection("recording", "")
        Services.Capture.setRegionSelection(Services.Capture.selectionScreenName,
            { x: 40, y: 60, width: 300, height: 200 })
        Services.Capture.confirmRegionSelection()
        check(regionVisible, "outline hidden immediately after confirmation")
    }

    onRegionVisibleChanged: {
        if (stage === 2 && !regionVisible)
            check(false, "outline blinked during recording startup")
    }

    Component.onCompleted: {
        Services.Capture.prepareScreenshot()
        check(Services.Capture.takingScreenshot, "no feedback while preparing capture")
        Services.Capture.takeScreenshot("full", "")
        check(Services.Capture.takingScreenshot, "no feedback before helper notification")
        stage = 1
    }

    Timer {
        interval: 10
        repeat: true
        running: !root.done
        onTriggered: {
            if (root.stage === 1 && !Services.Capture.takingScreenshot) {
                root.selectRecording()
                root.stage = 2
            } else if (root.stage === 2 && Services.Capture.recording
                && Services.Capture.startingRecordingGeometry === "") {
                root.check(Services.Capture.visibleRecordingGeometry === "40,60 300x200", "geometry lost at handoff")
                root.stage = 3
                Services.Capture.stopRecording()
            } else if (root.stage === 3 && !Services.Capture.recording) {
                root.selectRecording()
                root.stage = 4
            } else if (root.stage === 4 && Services.Capture.startingRecordingGeometry === "") {
                root.check(!Services.Capture.recording, "failed start reported as recording")
                Services.Capture.takeScreenshot("full", "")
                root.check(Services.Capture.takingScreenshot, "failed screenshot never showed feedback")
                root.stage = 5
            } else if (root.stage === 5 && !Services.Capture.takingScreenshot) {
                root.done = true
                console.log("CAPTURE_TEST_PASS")
            }
        }
    }

    Timer {
        interval: 12000
        running: !root.done
        onTriggered: root.check(false, "lifecycle timed out")
    }
}
