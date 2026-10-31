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

    activeView: expanded ? (expandedView === "media" ? mediaView : calendar)
        : volumeVisible ? volumeSlider : clockView

    function showVolume() {
        expanded = false
        volumeVisible = true
        volumeTimeout.restart()
    }

    function open(view) {
        expandedView = view
        expanded = true
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
            width: clockRow.implicitWidth + 16
            height: 32

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 8

                Item {
                    width: dateTime.implicitWidth + 8
                    height: 32

                    Text {
                        id: dateTime
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(clock.date, "MM/dd HH:mm ddd")
                        color: Theme.Colors.foreground
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.open("calendar")
                    }
                }

                Components.PlayingIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Services.Media.playing
                    playing: Services.Media.playing
                    levels: Services.Cava.groupedBars(5)
                    tooltip: "Now playing: " + Services.Media.title
                    onClicked: root.open("media")
                }
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
            active: root.expanded && root.expandedView === "media"
            onCloseRequested: root.expanded = false
        }
    ]
}
