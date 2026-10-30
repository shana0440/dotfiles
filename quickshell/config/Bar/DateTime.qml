import QtQuick
import Quickshell
import "../Theme" as Theme

Rectangle {
    width: dateTime.width + 24
    radius: 8
    color: Theme.Colors.background

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: dateTime
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "yyyy-MM-dd ddd HH:mm:ss")
        color: Theme.Colors.foreground
        font.pixelSize: 14
    }
}
