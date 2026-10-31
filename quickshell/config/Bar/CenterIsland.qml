import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme" as Theme
import "../Components" as Components

Components.Island {
    id: root

    property bool expanded: false
    property string expandedView: "calendar"
    property bool volumeVisible: false
    property string screenshotPath: ""
    readonly property bool screenshotVisible: screenshotDismissTimer.running
    readonly property bool showingMedia: expanded && expandedView === "media"

    activeView: {
        if (screenshotVisible)
            return screenshotNotification
        if (expanded)
            return showingMedia ? mediaView : calendar
        if (volumeVisible)
            return volumeSlider
        return clockView
    }

    function open(view) {
        screenshotDismissTimer.stop()
        expandedView = view
        expanded = true
    }

    function showScreenshot(filePath) {
        if (!filePath)
            return
        expanded = false
        volumeVisible = false
        volumeTimeout.stop()
        screenshotPath = filePath
        screenshotDismissTimer.restart()
    }

    function showVolume() {
        expanded = false
        volumeVisible = true
        volumeTimeout.restart()
    }

    IpcHandler {
        target: "screenshots"
        function captured(filePath: string) { root.showScreenshot(filePath) }
    }

    Timer {
        id: screenshotDismissTimer
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
        ScreenshotNotification {
            id: screenshotNotification
            filePath: root.screenshotPath
        }
    ]
}
