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
    property int availableHeight: 560
    readonly property bool captureNotificationVisible: notificationDismissTimer.running
    readonly property bool notificationVisible: captureNotificationVisible || Services.Notifications.previewVisible
    readonly property bool showingMedia: expanded && expandedView === "media"
    readonly property bool showingRecording: activeView === recordingView
    readonly property bool sideIslandsMerged: expanded || notificationVisible || Services.Capture.recording

    activeView: {
        if (captureNotificationVisible)
            return captureNotification
        if (expanded) {
            if (expandedView === "notifications")
                return notificationList
            return showingMedia ? mediaView : calendar
        }
        if (Services.Notifications.previewVisible)
            return toast
        if (volumeVisible)
            return volumeSlider
        if (Services.Capture.recording)
            return recordingView
        return clockView
    }

    // Pills: the recording indicator, and the toast (Ding's 22 px radius caps tall ones).
    targetRadius: showingRecording ? recordingView.height / 2
        : activeView === toast ? Math.min(22, toast.height / 2) : 8

    function close() {
        expanded = false
        notificationDismissTimer.stop()
        Services.Notifications.hidePreview()
    }

    function open(view) {
        notificationDismissTimer.stop()
        Services.Notifications.hidePreview()
        expandedView = view
        expanded = true
    }

    Connections {
        target: Services.Notifications
        function onReceived() {
            notificationDismissTimer.stop()
            root.volumeVisible = false
            volumeTimeout.stop()
            root.expanded = false
        }
    }

    function showCaptureNotification(filePath, previewPath, fallbackIcon) {
        if (!filePath)
            return
        expanded = false
        Services.Notifications.hidePreview()
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
            onStopRequested: Services.Capture.stopRecording()
        },
        CaptureNotification {
            id: captureNotification
        },
        NotificationView {
            id: notificationList
            maximumHeight: root.availableHeight
            onCloseRequested: root.close()
        },
        DingToast {
            id: toast
            revealWidth: root.width
            revealHeight: root.height
            onListRequested: root.open("notifications")
            onGesture: kind => {
                if (kind === "error")
                    root.kick(380, 0)
                else if (kind === "repeat")
                    root.kick(0, 240)
            }
        }
    ]
}
