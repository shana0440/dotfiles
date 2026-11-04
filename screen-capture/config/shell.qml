import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Services" as Services

ShellRoot {
    id: root

    property bool menuOpen: true
    property string message: ""

    component CaptureButton: Button {
        palette.button: "#292929"
        palette.buttonText: "white"
        palette.highlight: "#a78bfa"
        implicitHeight: 40
    }

    function openMenu() {
        if (Services.Capture.selectingRegion)
            Services.Capture.cancelRegionSelection()
        // Remap even when already open, so launcher activation brings it forward.
        menuOpen = false
        menu.minimized = false
        Qt.callLater(() => { root.menuOpen = true })
    }

    function capture(kind, mode) {
        if (pendingCapture.running)
            return
        message = ""
        menuOpen = false
        pendingCapture.kind = kind
        pendingCapture.mode = mode
        pendingCapture.outputName = output.currentText
        pendingCapture.restart()
    }

    // Allow the application window to disappear before starting capture.
    Timer {
        id: pendingCapture
        property string kind
        property string mode
        property string outputName
        interval: 180
        onTriggered: {
            if (kind === "screenshot")
                Services.Capture.takeScreenshot(mode, outputName)
            else
                Services.Capture.startRecording(mode, outputName)
        }
    }

    IpcHandler {
        target: "capture"
        function openMenu(): void { root.openMenu() }
        function selectRegion(kind: string): void {
            root.menuOpen = false
            Services.Capture.beginRegionSelection(kind, output.currentText)
        }
        function stop(): void { Services.Capture.stopRecording() }
        function status(): string {
            return JSON.stringify({
                recording: Services.Capture.recording,
                mode: Services.Capture.recordingMode,
                startedAtMs: Services.Capture.recordingStartedAtMs,
                geometry: Services.Capture.recordingGeometry
            })
        }
    }

    Connections {
        target: Services.Capture
        function onScreenshotSaved(filePath) { root.message = "Saved: " + filePath }
        function onErrorOccurred(message) {
            root.message = message
            root.menuOpen = true
        }
    }

    CaptureOverlay {}

    FloatingWindow {
        id: menu
        visible: root.menuOpen
        title: "Screen Capture"
        implicitWidth: 420
        implicitHeight: content.implicitHeight + 40
        minimumSize: Qt.size(implicitWidth, implicitHeight)
        maximumSize: minimumSize
        color: "#121212"
        onClosed: root.menuOpen = false

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Label {
                text: "Screen Capture"
                color: "white"
                font.pixelSize: 22
                font.bold: true
            }
            Label {
                text: "Screenshots and screen recordings"
                color: "#b0b0b0"
            }
            ComboBox {
                id: output
                Layout.fillWidth: true
                model: Quickshell.screens.map(screen => screen.name)
                Accessible.name: "Screen to record"
                palette.button: "#292929"
                palette.buttonText: "white"
                palette.base: "#292929"
                palette.text: "white"
                palette.highlight: "#a78bfa"
            }
            GridLayout {
                columns: 2
                Layout.fillWidth: true
                CaptureButton {
                    id: screenshotAll
                    text: "1 · Screenshot all"
                    Layout.fillWidth: true
                    enabled: !Services.Capture.takingScreenshot
                    onClicked: root.capture("screenshot", "full")
                    Shortcut { sequence: "1"; enabled: root.menuOpen && screenshotAll.enabled; onActivated: screenshotAll.clicked() }
                }
                CaptureButton {
                    id: screenshotRegion
                    text: "2 · Screenshot region"
                    Layout.fillWidth: true
                    enabled: !Services.Capture.takingScreenshot
                    onClicked: root.capture("screenshot", "region")
                    Shortcut { sequence: "2"; enabled: root.menuOpen && screenshotRegion.enabled; onActivated: screenshotRegion.clicked() }
                }
                CaptureButton {
                    id: recordScreen
                    text: "3 · Record screen"
                    Layout.fillWidth: true
                    enabled: output.currentText.length > 0 && !Services.Capture.recording && !Services.Capture.recordingCommandRunning
                    onClicked: root.capture("recording", "full")
                    Shortcut { sequence: "3"; enabled: root.menuOpen && recordScreen.enabled; onActivated: recordScreen.clicked() }
                }
                CaptureButton {
                    id: recordRegion
                    text: "4 · Record region"
                    Layout.fillWidth: true
                    enabled: !Services.Capture.recording && !Services.Capture.recordingCommandRunning
                    onClicked: root.capture("recording", "region")
                    Shortcut { sequence: "4"; enabled: root.menuOpen && recordRegion.enabled; onActivated: recordRegion.clicked() }
                }
            }
            RowLayout {
                visible: Services.Capture.recording
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    color: "#ff7373"
                    text: "Recording · " + Math.floor(Services.Capture.recordingElapsedSeconds / 60)
                        + ":" + String(Services.Capture.recordingElapsedSeconds % 60).padStart(2, "0")
                }
                CaptureButton {
                    text: Services.Capture.recordingCommandRunning ? "Stopping…" : "Stop recording"
                    enabled: !Services.Capture.recordingCommandRunning
                    onClicked: Services.Capture.stopRecording()
                }
            }
            Label {
                visible: root.message.length > 0
                text: root.message
                color: "#b0b0b0"
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
            }
            Label {
                text: "Esc to dismiss · Recording includes system audio"
                color: "#b0b0b0"
                font.pixelSize: 11
            }
        }
        Shortcut { sequence: "Escape"; enabled: root.menuOpen; onActivated: root.menuOpen = false }
    }
}
