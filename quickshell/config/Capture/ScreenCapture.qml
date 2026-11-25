import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Services" as Services
import "../Theme" as Theme
import "../Components" as Components

Scope {
    id: root

    property bool menuOpen: false
    property string message: ""
    property string targetMode: "full"
    property string captureKind: "screenshot"
    property string outputName: Quickshell.screens[0]?.name ?? ""
    readonly property var outputScreen: Quickshell.screens.find(screen => screen.name === outputName) ?? Quickshell.screens[0]
    readonly property bool regionMode: targetMode === "region"
    readonly property bool windowMode: targetMode === "window"
    readonly property bool recordingMode: captureKind === "recording"
    readonly property bool canChooseMode: menuOpen && Services.Capture.previewActive && !Services.Capture.recording
    readonly property bool selectionMissing: windowMode ? Services.Capture.selectedWindow === null
        : regionMode && (Services.Capture.selectionRect.width <= 0 || Services.Capture.selectionRect.height <= 0)
    readonly property var targets: [
        { value: "full", label: "Full screen", icon: "screen", key: "1" },
        { value: "window", label: "Window", icon: "window", key: "2" },
        { value: "region", label: "Select range", icon: "region", key: "3" }
    ]
    readonly property var kinds: [
        { value: "screenshot", label: "Screenshot", icon: "screenshot", key: "F1" },
        { value: "recording", label: "Recording", icon: "record", key: "F2" }
    ]

    function openMenu() {
        message = ""
        if (menuOpen && !Services.Capture.previewActive && !Services.Capture.recording) {
            menuOpen = false
            reopenDelay.restart()
        } else {
            Services.Capture.openPreview()
        }
    }

    function configureSelection() {
        Services.Capture.cancelRegionSelection()
        Services.Capture.cancelWindowSelection()
        message = ""
        if (!Services.Capture.previewActive || !outputScreen)
            return
        if (windowMode) {
            Services.Capture.beginWindowSelection(captureKind)
            message = Services.Capture.preview?.windowError ?? ""
        } else if (regionMode) {
            Services.Capture.beginRegionSelection(captureKind, outputName)
        }
    }

    function selectTarget(value) {
        if (!canChooseMode || value === targetMode || !targets.some(target => target.value === value))
            return
        targetMode = value
        configureSelection()
    }

    function selectKind(value) {
        if (!canChooseMode || value === captureKind || !kinds.some(kind => kind.value === value))
            return
        captureKind = value
        if (Services.Capture.selectingWindow)
            Services.Capture.windowSelectionKind = value
        if (Services.Capture.selectingRegion)
            Services.Capture.selectionKind = value
    }

    function dismiss() {
        menuOpen = false
        Services.Capture.cancelRegionSelection()
        Services.Capture.cancelWindowSelection()
        Services.Capture.dismissPreview()
    }

    function capture() {
        if (Services.Capture.recording) {
            Services.Capture.stopRecording()
            return
        }
        if (pendingRecording.running || Services.Capture.takingScreenshot)
            return
        if (!Services.Capture.previewActive || selectionMissing)
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

    Binding {
        target: Services.Capture
        property: "toolbarVisible"
        value: root.menuOpen
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
        function open(): void { root.openMenu() }
        function close(): void { if (root.menuOpen) root.dismiss() }
        function stop(): void { Services.Capture.stopRecording() }
        function selectTarget(value: string): void { root.selectTarget(value) }
        function selectKind(value: string): void { root.selectKind(value) }
        function state(): string {
            return JSON.stringify({
                target: root.targetMode,
                kind: root.captureKind,
                recording: Services.Capture.recording,
                mode: Services.Capture.recordingMode,
                startedAtMs: Services.Capture.recordingStartedAtMs,
                geometry: Services.Capture.recordingGeometry,
                window: Services.Capture.recordingWindow,
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

    ScreenshotEditor {}

    CaptureOverlay {
        onConfirmed: root.capture()
        onCancelled: root.dismiss()
    }

    PanelWindow {
        id: panel
        visible: root.menuOpen
        screen: root.outputScreen
        anchors.bottom: true
        margins.bottom: 36
        implicitWidth: Math.min(content.implicitWidth + 2 * content.anchors.margins + 2 * surface.anchors.margins,
            (root.outputScreen?.width ?? 1280) - 24)
        implicitHeight: content.implicitHeight + 2 * content.anchors.margins + 2 * surface.anchors.margins
        color: Theme.Colors.transparent
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-capture-toolbar"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        mask: Region { item: surface }

        Components.Surface {
            id: surface
            anchors.fill: parent
            anchors.margins: 4
            radius: 12
            color: Theme.Colors.panel
            border.color: Theme.Colors.ring
            border.width: 1

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    visible: root.message.length > 0
                    text: root.message
                    textFormat: Text.PlainText
                    color: Theme.Colors.foreground
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                    Layout.maximumWidth: actions.implicitWidth
                }

                RowLayout {
                    id: actions
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Repeater {
                        model: root.targets
                        ModeButton {
                            id: targetButton
                            required property var modelData
                            visible: !Services.Capture.recording
                            enabled: root.canChooseMode
                            icon: modelData.icon
                            tooltip: modelData.label
                            shortcutKey: modelData.key
                            highlighted: root.targetMode === modelData.value
                            onClicked: root.selectTarget(modelData.value)
                            Shortcut {
                                sequence: targetButton.shortcutKey
                                context: Qt.ApplicationShortcut
                                enabled: targetButton.enabled
                                onActivated: root.selectTarget(targetButton.modelData.value)
                            }
                        }
                    }
                    Rectangle {
                        visible: !Services.Capture.recording
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 28
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        color: Theme.Colors.track
                    }
                    Repeater {
                        model: root.kinds
                        ModeButton {
                            id: kindButton
                            required property var modelData
                            visible: !Services.Capture.recording
                            enabled: root.canChooseMode
                            icon: modelData.icon
                            tooltip: modelData.label
                            shortcutKey: modelData.key
                            highlighted: root.captureKind === modelData.value
                            onClicked: root.selectKind(modelData.value)
                            Shortcut {
                                sequence: kindButton.shortcutKey
                                context: Qt.ApplicationShortcut
                                enabled: kindButton.enabled
                                onActivated: root.selectKind(kindButton.modelData.value)
                            }
                        }
                    }
                    Rectangle {
                        id: captureButton
                        readonly property string label: Services.Capture.recording ? "Stop recording"
                            : root.recordingMode ? "Start recording" : "Take screenshot"
                        enabled: !Services.Capture.recordingCommandRunning
                            && (Services.Capture.recording || (Services.Capture.previewActive && !root.selectionMissing))
                        Layout.leftMargin: 4
                        Layout.preferredWidth: Services.Capture.recording ? 80 : 44
                        Layout.preferredHeight: 44
                        radius: 8
                        color: Theme.Colors.foreground
                        opacity: !enabled ? 0.4 : captureMouse.pressed ? 0.75 : captureMouse.containsMouse ? 0.88 : 1
                        Accessible.role: Accessible.Button
                        Accessible.name: label

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Components.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                action: Services.Capture.recording ? "stop" : root.recordingMode ? "record" : "screenshot"
                                iconColor: Theme.Colors.background
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Services.Capture.recording
                                text: Services.Capture.recordingElapsedSeconds + "s"
                                color: Theme.Colors.background
                                font.family: Theme.Fonts.family
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }

                        Components.Tooltip {
                            text: captureButton.label + " (Enter)"
                            shown: captureMouse.containsMouse
                            alignment: Qt.AlignHCenter
                        }

                        MouseArea {
                            id: captureMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.capture()
                        }
                    }
                }
            }
        }
        Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: root.menuOpen; onActivated: root.dismiss() }
        Shortcut { sequence: "Return"; context: Qt.ApplicationShortcut; enabled: root.menuOpen; onActivated: root.capture() }
        Shortcut { sequence: "Enter"; context: Qt.ApplicationShortcut; enabled: root.menuOpen; onActivated: root.capture() }
    }
}
