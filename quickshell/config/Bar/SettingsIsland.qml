import QtQuick
import "../Components" as Components
import "../Services" as Services

Components.MergeableCircle {
    id: root

    readonly property bool loading: Services.Capture.takingScreenshot === true
    signal clicked()
    animateMerge: !loading

    Loader {
        objectName: "captureIndicator"
        anchors.fill: parent
        sourceComponent: root.loading ? spinnerContent : settingsContent
    }

    Component {
        id: settingsContent

        Components.IconButton {
            objectName: "captureControlsButton"
            radius: height / 2
            icon: "settings"
            tooltip: "Capture controls"
            enabled: !Services.Capture.recordingCommandRunning
            onClicked: root.clicked()
        }
    }

    Component {
        id: spinnerContent

        Item {
            objectName: "screenshotLoadingContent"

            Components.LoadingSpinner {
                objectName: "screenshotSpinner"
                anchors.centerIn: parent
                width: 20
                height: 20
            }
        }
    }
}
