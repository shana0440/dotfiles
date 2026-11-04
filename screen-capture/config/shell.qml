import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Capture" as CaptureComponents
import "Services" as Services

ShellRoot {
    id: root

    property bool menuOpen: false
    // Set per invocation by `screen-capture --no-stop-toolbar` when another UI (the
    // bar) offers Stop. The environment value only covers a fresh start.
    property bool hideStopToolbar: Quickshell.env("SCREEN_CAPTURE_HIDE_STOP_TOOLBAR") === "1"
    property string message: ""
    property int mode: 0
    property string outputName: Quickshell.screens[0]?.name ?? ""
    readonly property var outputScreen: Quickshell.screens.find(screen => screen.name === outputName) ?? Quickshell.screens[0]
    readonly property bool regionMode: modes[mode].region
    readonly property bool windowMode: modes[mode].window
    readonly property bool recordingMode: modes[mode].recording
    readonly property var modes: [
        { label: "1 · Capture entire desktop", region: false, window: false, recording: false },
        { label: "2 · Capture a window", region: false, window: true, recording: false },
        { label: "3 · Capture selected portion", region: true, window: false, recording: false },
        { label: "4 · Record entire screen", region: false, window: false, recording: true },
        { label: "5 · Record a window", region: false, window: true, recording: true },
        { label: "6 · Record selected portion", region: true, window: false, recording: true }
    ]

    function openMenu() {
        message = ""
        if (menuOpen && !Services.Capture.previewActive && !Services.Capture.recording) {
            // Do not bake a recording/error toolbar into the next frozen frame.
            menuOpen = false
            reopenDelay.restart()
        } else {
            Services.Capture.openPreview()
        }
    }

    function configureSelection() {
        const previous = Services.Capture.selectingRegion ? Services.Capture.selectionRect : null
        const previousScreen = Services.Capture.selectionScreenName
        Services.Capture.cancelRegionSelection()
        Services.Capture.cancelWindowSelection()
        if (!Services.Capture.previewActive || !outputScreen)
            return
        if (windowMode) {
            Services.Capture.beginWindowSelection(recordingMode ? "recording" : "screenshot")
            message = Services.Capture.preview?.windowError ?? ""
            return
        }
        if (!regionMode)
            return
        Services.Capture.beginRegionSelection(recordingMode ? "recording" : "screenshot", outputName)
        Services.Capture.setRegionSelection(outputName, previous && previousScreen === outputName ? previous : {
            x: outputScreen.width * 0.2, y: outputScreen.height * 0.2,
            width: outputScreen.width * 0.6, height: outputScreen.height * 0.5
        })
    }

    function chooseMode(index) {
        mode = index
        message = ""
        configureSelection()
    }

    function dismiss() {
        menuOpen = false
        Services.Capture.cancelRegionSelection()
        Services.Capture.cancelWindowSelection()
        Services.Capture.dismissPreview()
    }

    function capture() {
        // Stopping must stay available even while another capture is finishing.
        if (Services.Capture.recording) {
            Services.Capture.stopRecording()
            return
        }
        if (pendingRecording.running || Services.Capture.takingScreenshot)
            return
        if (!Services.Capture.previewActive || (windowMode && Services.Capture.selectedWindow === null))
            return
        menuOpen = false
        if (windowMode) {
            if (recordingMode) {
                pendingRecording.windowIdentifier = Services.Capture.beginWindowRecording()
                if (pendingRecording.windowIdentifier)
                    pendingRecording.restart()
            } else {
                Services.Capture.captureWindowScreenshot()
            }
        } else if (regionMode) {
            Services.Capture.confirmRegionSelection()
        } else if (recordingMode) {
            Services.Capture.dismissPreview()
            pendingRecording.outputName = outputName
            pendingRecording.windowIdentifier = ""
            pendingRecording.restart()
        } else {
            Services.Capture.takeScreenshot("full", outputName)
        }
    }

    Component.onCompleted: {
        if (Quickshell.env("SCREEN_CAPTURE_BACKGROUND") !== "1")
            openMenu()
    }
    Component.onDestruction: Services.Capture.cleanupPreview()

    Timer {
        id: reopenDelay
        interval: 80
        onTriggered: Services.Capture.openPreview()
    }

    Timer {
        id: pendingRecording
        property string outputName
        property string windowIdentifier: ""
        interval: 180
        onTriggered: {
            if (windowIdentifier)
                Services.Capture.startWindowRecording(windowIdentifier)
            else
                Services.Capture.startRecording("full", outputName)
        }
    }

    IpcHandler {
        target: "capture"
        function openMenu(hideStopToolbar: bool): void {
            root.hideStopToolbar = hideStopToolbar
            root.openMenu()
        }
        function selectRegion(kind: string): void {
            root.mode = kind === "recording" ? 5 : 2
            root.openMenu()
        }
        function stop(): void { Services.Capture.stopRecording() }
        function status(): string {
            return JSON.stringify({
                recording: Services.Capture.recording,
                mode: Services.Capture.recordingMode,
                startedAtMs: Services.Capture.recordingStartedAtMs,
                geometry: Services.Capture.recordingGeometry,
                preview: Services.Capture.previewActive
            })
        }
    }

    Connections {
        target: Services.Capture
        function onPreviewReady() {
            root.configureSelection()
            root.menuOpen = true
        }
        function onRecordingChanged() {
            if (!Services.Capture.recording && root.menuOpen)
                root.openMenu()
        }
        function onScreenshotSaved(filePath) { root.message = "Saved: " + filePath }
        function onErrorOccurred(message) {
            root.message = message
            root.menuOpen = true
        }
        function onSelectedWindowChanged() {
            if (Services.Capture.selectingWindow && Services.Capture.selectedWindow)
                root.outputName = Services.Capture.selectedWindow.screenName
        }
        function onSelectionScreenNameChanged() {
            if (Services.Capture.selectingRegion)
                root.outputName = Services.Capture.selectionScreenName
        }
    }

    CaptureOverlay {
        onConfirmed: root.capture()
        onCancelled: root.dismiss()
    }

    PanelWindow {
        id: panel
        // Keep Stop reachable while recording, unless another UI provides it.
        visible: root.menuOpen || (Services.Capture.recording && !root.hideStopToolbar)
        screen: root.outputScreen
        anchors.bottom: true
        margins.bottom: 36
        implicitWidth: Math.min(actions.implicitWidth + 24, (root.outputScreen?.width ?? 1280) - 24)
        implicitHeight: 70 + (root.message ? 48 : 0)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "screen-capture-toolbar"
        WlrLayershell.layer: WlrLayer.Overlay
        // The idle recording control must not steal desktop keyboard focus, but a
        // menu the user reopened must receive Escape/Enter.
        WlrLayershell.keyboardFocus: Services.Capture.recording && !root.menuOpen
            ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

        // Only the rounded toolbar accepts pointer input.
        mask: Region { item: surface }

        Rectangle {
            id: surface
            anchors.fill: parent
            anchors.margins: 4
            radius: 13
            color: "#f238383f"
            border.color: "#777780"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Label {
                    visible: root.message.length > 0
                    text: root.message
                    color: "#dddde2"
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                RowLayout {
                    id: actions
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Repeater {
                        model: root.modes
                        RowLayout {
                            id: modeGroup
                            required property var modelData
                            required property int index
                            visible: !Services.Capture.recording
                            spacing: 6

                            Rectangle {
                                visible: modeGroup.index === 3
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 34
                                color: "#74747c"
                            }
                            CaptureComponents.ModeButton {
                                text: modeGroup.modelData.label
                                region: modeGroup.modelData.region
                                windowMode: modeGroup.modelData.window
                                recording: modeGroup.modelData.recording
                                checked: root.mode === modeGroup.index
                                enabled: !Services.Capture.recording && Services.Capture.previewActive
                                onClicked: root.chooseMode(modeGroup.index)
                                Shortcut {
                                    sequence: String(modeGroup.index + 1)
                                    context: Qt.ApplicationShortcut
                                    enabled: root.menuOpen && !Services.Capture.recording
                                    onActivated: root.chooseMode(modeGroup.index)
                                }
                            }
                        }
                    }
                    Button {
                        id: captureButton
                        hoverEnabled: true
                        text: Services.Capture.recording ? "Stop · " + Services.Capture.recordingElapsedSeconds + "s"
                            : root.recordingMode ? "Record" : "Capture"
                        enabled: !Services.Capture.recordingCommandRunning
                            && (Services.Capture.recording || (Services.Capture.previewActive
                                && (!root.windowMode || Services.Capture.selectedWindow !== null)))
                        palette.buttonText: "#eeeef2"
                        background: Rectangle {
                            radius: 7
                            color: captureButton.down ? "#64646e"
                                : captureButton.hovered ? "#52525a" : "transparent"
                            border.width: captureButton.visualFocus ? 1 : 0
                            border.color: "#c4b5fd"
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        implicitHeight: 42
                        Layout.preferredWidth: 98
                        onClicked: root.capture()
                    }
                }
            }
        }
        // The selector and toolbar are separate native windows; shortcuts must
        // keep working after a drag gives the selector keyboard focus.
        Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: root.menuOpen; onActivated: root.dismiss() }
        Shortcut { sequence: "Return"; context: Qt.ApplicationShortcut; enabled: root.menuOpen; onActivated: root.capture() }
        Shortcut { sequence: "Enter"; context: Qt.ApplicationShortcut; enabled: root.menuOpen; onActivated: root.capture() }
    }
}
