import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Components.Island {
    id: root

    property bool expanded: false
    property string expandedView: "calendar"
    property bool volumeVisible: false
    readonly property bool notificationVisible: notificationDismissTimer.running
    readonly property bool showingMedia: expanded && expandedView === "media"
    readonly property bool showingRecording: activeView === recordingView
    readonly property bool sideIslandsMerged: expanded || notificationVisible || Services.Capture.recording
    signal captureRequested(string action, string mode)

    activeView: {
        if (notificationVisible)
            return captureNotification
        if (expanded) {
            if (expandedView === "capture")
                return captureMenu
            return showingMedia ? mediaView : calendar
        }
        if (volumeVisible)
            return volumeSlider
        if (Services.Capture.recording)
            return recordingView
        return clockView
    }

    radius: showingRecording ? recordingView.height / 2 : 8
    Behavior on radius {
        NumberAnimation { duration: root.resizeDuration; easing.type: Easing.OutCubic }
    }

    function open(view) {
        notificationDismissTimer.stop()
        expandedView = view
        expanded = true
    }

    function showCaptureNotification(filePath, previewPath, fallbackIcon) {
        if (!filePath)
            return
        expanded = false
        volumeVisible = false
        volumeTimeout.stop()
        captureNotification.filePath = filePath
        captureNotification.previewPath = previewPath
        captureNotification.fallbackIcon = fallbackIcon
        notificationDismissTimer.restart()
    }

    function showVolume() {
        expanded = false
        volumeVisible = true
        volumeTimeout.restart()
    }

    Connections {
        target: Services.Capture
        function onScreenshotSaved(filePath) {
            root.showCaptureNotification(filePath, filePath, "screenshot")
        }
    }

    IpcHandler {
        target: "recordings"
        function saved(filePath: string, thumbnailPath: string) {
            root.showCaptureNotification(filePath, thumbnailPath, "record")
        }
    }

    Timer {
        id: notificationDismissTimer
        interval: 2000
    }

    Timer {
        id: volumeTimeout
        interval: 1000
        onTriggered: {
            if (volumeSlider.interacting)
                restart()
            else
                root.volumeVisible = false
        }
    }

    onExpandedChanged: {
        if (expanded && expandedView === "calendar")
            calendar.displayedMonth = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    views: [
        Item {
            id: clockView
            width: dateTime.implicitWidth + 24
            height: 32

            Text {
                id: dateTime
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "ddd MM/dd hh:mm A")
                color: Theme.Colors.foreground
                font.pixelSize: 14
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.open("calendar")
            }
        },
        VolumeSlider {
            id: volumeSlider
            width: 280
            height: 32
            onAdjusted: root.showVolume()
        },
        Calendar {
            id: calendar
            today: clock.date
            onCloseRequested: root.expanded = false
        },
        MediaView {
            id: mediaView
            active: root.showingMedia
            onCloseRequested: root.expanded = false
        },
        RecordingView {
            id: recordingView
            elapsedSeconds: Services.Capture.recordingElapsedSeconds
            stopping: Services.Capture.recordingCommandRunning
            onStopRequested: root.captureRequested("stopRecording", "")
            onControlsRequested: root.open("capture")
        },
        CaptureMenu {
            id: captureMenu
            onCaptureRequested: (action, mode) => root.captureRequested(action, mode)
        },
        CaptureNotification {
            id: captureNotification
        }
    ]
}
