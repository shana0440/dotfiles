import QtQuick
import Quickshell
import Quickshell.Io
import "Services" as Services

ShellRoot {
    id: root
    property bool submitted: false
    property bool done: false

    IpcHandler {
        target: "queueTest"
        function submit(middle: string) {
            Services.Capture.takeScreenshot("full", "")
            remaining.middle = middle
            remaining.start()
        }
    }

    Timer {
        id: remaining
        property string middle: "full"
        interval: 60
        onTriggered: {
            Services.Capture.runScreenshot(middle === "missing"
                ? ["/nonexistent-quickshell-test-screenshot-helper"] : ["hypr-screenshot", middle])
            Services.Capture.takeScreenshot("full", "")
            root.submitted = true
        }
    }

    Connections {
        target: Services.Capture
        function onTakingScreenshotChanged() {
            if (root.submitted && !Services.Capture.takingScreenshot && !root.done) {
                root.done = true
                console.log("SCREENSHOT_QUEUE_DONE")
            }
        }
    }
}
