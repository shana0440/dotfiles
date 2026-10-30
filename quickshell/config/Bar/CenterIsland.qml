import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Theme" as Theme

Rectangle {
    id: root

    property bool expanded: false
    property bool volumeVisible: false

    // Detect clicks outside the bar window, including through its transparent gaps.
    HyprlandFocusGrab {
        active: root.expanded
        windows: root.QsWindow.window ? [root.QsWindow.window] : []
        onCleared: root.expanded = false
    }

    // The other islands share our window, so handle those clicks locally.
    TapHandler {
        parent: root.parent
        enabled: root.expanded
        acceptedButtons: Qt.AllButtons
        gesturePolicy: TapHandler.DragThreshold
        onTapped: eventPoint => {
            const position = root.mapFromItem(parent, eventPoint.position.x, eventPoint.position.y)
            if (!root.contains(position))
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
        if (expanded)
            calendar.displayedMonth = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
    }

    width: expanded || volumeVisible ? 280 : dateTime.implicitWidth + 24
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
        opacity: root.expanded || root.volumeVisible ? 0 : 1
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
            enabled: !root.expanded && !root.volumeVisible
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = true
        }
    }

    VolumeSlider {
        id: volumeSlider
        anchors.horizontalCenter: parent.horizontalCenter
        width: 256
        height: 32
        opacity: root.volumeVisible ? 1 : 0
        visible: opacity > 0
        enabled: root.volumeVisible
        onAdjusted: root.showVolume()

        Behavior on opacity {
            NumberAnimation { duration: 160 }
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
