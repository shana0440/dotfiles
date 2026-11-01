import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    signal captureRequested(string action, string mode)

    implicitWidth: actions.implicitWidth + 24
    implicitHeight: 48

    Row {
        id: actions
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: [
                { action: "takeScreenshot", mode: "full", icon: "screenshot", label: "Screenshot all screens" },
                { action: "takeScreenshot", mode: "region", icon: "screenshotRegion", label: "Screenshot a region" },
                { action: "startRecording", mode: "full", icon: "record", label: "Record full screen" },
                { action: "startRecording", mode: "region", icon: "recordRegion", label: "Record a region" }
            ]

            Components.IconButton {
                id: actionButton
                required property int index
                required property var modelData
                readonly property bool recordingAction: modelData.action === "startRecording"
                readonly property bool stopsRecording: recordingAction && Services.Capture.recording
                    && Services.Capture.recordingMode === modelData.mode

                icon: stopsRecording ? "stop" : modelData.icon
                tooltip: (index + 1) + " · " + (stopsRecording ? "Stop recording" : modelData.label)
                highlighted: stopsRecording
                enabled: !recordingAction || (!Services.Capture.recordingCommandRunning
                    && (!Services.Capture.recording || stopsRecording))
                onClicked: root.captureRequested(stopsRecording ? "stopRecording" : modelData.action, modelData.mode)

                Shortcut {
                    sequence: String(actionButton.index + 1)
                    context: Qt.WindowShortcut
                    enabled: actionButton.enabled && actionButton.visible
                    autoRepeat: false
                    onActivated: actionButton.clicked()
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 3
                    anchors.bottomMargin: 1
                    text: actionButton.index + 1
                    color: Theme.Colors.foreground
                    font.pixelSize: 9
                    opacity: 0.65
                }
            }
        }
    }
}
