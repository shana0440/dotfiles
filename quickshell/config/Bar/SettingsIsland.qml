import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Components.MergeableCircle {
    id: root

    signal clicked()
    signal stopRecordingRequested()

    Components.IconButton {
        anchors.fill: parent
        radius: height / 2
        icon: Services.Capture.recording ? "stop" : "settings"
        iconColor: Services.Capture.recording ? Theme.Colors.accent : Theme.Colors.foreground
        tooltip: Services.Capture.recording ? "Stop recording" : "Capture controls"
        enabled: !Services.Capture.recordingCommandRunning
        onClicked: {
            if (Services.Capture.recording)
                root.stopRecordingRequested()
            else
                root.clicked()
        }
    }
}
