import QtQuick
import "../Components" as Components
import "../Services" as Services

Components.MergeableCircle {
    id: root

    signal clicked()

    Components.IconButton {
        anchors.fill: parent
        radius: height / 2
        icon: "settings"
        tooltip: "Capture controls"
        enabled: !Services.Capture.recordingCommandRunning
        onClicked: root.clicked()
    }
}
