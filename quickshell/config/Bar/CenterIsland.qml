import QtQuick
import Quickshell
import "../Theme" as Theme

Rectangle {
    id: root

    property bool expanded: false

    onExpandedChanged: {
        if (expanded)
            calendar.displayedMonth = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
    }

    width: expanded ? 280 : dateTime.implicitWidth + 24
    height: expanded ? 300 : 32
    radius: 8
    color: Theme.Colors.background
    clip: true

    Behavior on width {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: dateTime.implicitWidth + 24
        height: 32
        opacity: root.expanded ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        Text {
            id: dateTime
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "MM/dd HH:mm ddd")
            color: Theme.Colors.foreground
            font.pixelSize: 14
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.expanded
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = true
        }
    }

    Calendar {
        id: calendar
        anchors.horizontalCenter: parent.horizontalCenter
        width: 280
        height: 300
        today: clock.date
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        enabled: root.expanded
        onCloseRequested: root.expanded = false

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }
}
