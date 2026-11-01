import QtQuick
import Quickshell
import Quickshell.Io
import "Services" as Services

ShellRoot {
    IpcHandler {
        target: "failureTest"
        function startRegion() {
            Services.Capture.beginRegionSelection("recording", "")
            Services.Capture.setRegionSelection(Services.Capture.selectionScreenName,
                { x: 40, y: 60, width: 300, height: 200 })
            Services.Capture.confirmRegionSelection()
        }
        function pending(): bool { return Services.Capture.startingRecordingGeometry.length > 0 }
        function malformedStatus(): string {
            // Test boundary: report the propagated decoding error to the assertion.
            try {
                Services.Capture.applyRecordingStatus("{invalid")
            } catch (error) {
                return error.name
            }
            return "NO_ERROR"
        }
    }
    Component.onCompleted: {
        Quickshell.watchFiles = false
        console.log("FAILURE_TEST_READY", Services.Media.playing)
    }
}
