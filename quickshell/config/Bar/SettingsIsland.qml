import QtQuick
import "../Components" as Components
import "../Services" as Services

Components.MergeableCircle {
    id: root

    signal clicked()
    animateMerge: !Services.Capture.takingScreenshot

    Components.IconButton {
        objectName: "captureControlsButton"
        visible: !Services.Capture.takingScreenshot
        anchors.fill: parent
        radius: height / 2
        icon: "settings"
        tooltip: "Capture controls"
        enabled: !Services.Capture.recordingCommandRunning && !Services.Capture.takingScreenshot
        onClicked: root.clicked()
    }

    Components.LoadingSpinner {
        objectName: "screenshotSpinner"
        anchors.centerIn: parent
        width: 20
        height: 20
        visible: Services.Capture.takingScreenshot
    }
}
