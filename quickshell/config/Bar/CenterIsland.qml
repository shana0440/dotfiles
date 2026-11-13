import QtQuick
import Quickshell
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Components.Island {
    id: root

    property bool expanded: false
    property string expandedView: "calendar"
    property bool volumeVisible: false
    property int availableHeight: 560
    readonly property bool notificationVisible: Services.Notifications.previewVisible
    readonly property bool showingMedia: expanded && expandedView === "media"
    readonly property bool showingRecording: activeView === recordingView
    readonly property bool sideIslandsMerged: expanded || notificationVisible || Services.Capture.recording

    activeView: {
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
        Services.Notifications.hidePreview()
    }

    function open(view) {
        Services.Notifications.hidePreview()
        expandedView = view
        expanded = true
    }

    Connections {
        target: Services.Notifications
        function onReceived() {
            root.volumeVisible = false
            volumeTimeout.stop()
            root.expanded = false
        }
    }

    function showVolume() {
        expanded = false
        volumeVisible = true
        volumeTimeout.restart()
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
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "ddd d MMM · hh:mm A")
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
