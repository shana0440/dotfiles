import QtQuick
import Quickshell
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: bar

    property real pt: 1
    property bool active: false
    property color ink: "black"

    SystemClock {
        id: clock
        enabled: bar.active
        precision: SystemClock.Minutes
    }

    Rectangle {
        id: island
        anchors { top: parent.top; topMargin: 11 * bar.pt; horizontalCenter: parent.horizontalCenter }
        width: 124 * bar.pt
        height: 36 * bar.pt
        radius: height / 2
        color: "black"
    }

    Text {
        anchors { verticalCenter: island.verticalCenter; horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: -bar.width * 0.3 }
        text: Qt.formatTime(clock.date, "h:mm")
        color: bar.ink
        font { family: Theme.Fonts.family; weight: Font.Bold; pixelSize: 17 * bar.pt }
    }

    Row {
        anchors { verticalCenter: island.verticalCenter; horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: bar.width * 0.3 }
        spacing: 5 * bar.pt

        Row {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2 * bar.pt
            spacing: 2 * bar.pt
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    anchors.bottom: parent.bottom
                    width: 3.5 * bar.pt
                    height: (5 + index * 3) * bar.pt
                    radius: 1 * bar.pt
                    color: bar.ink
                }
            }
        }
        Components.Icon {
            action: "wifi"
            width: 17 * bar.pt
            height: width
            iconColor: bar.ink
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 27 * bar.pt
            height: 13 * bar.pt
            Rectangle {
                width: parent.width - 3 * bar.pt
                height: parent.height
                radius: 4 * bar.pt
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(bar.ink, 0.4)
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2 * bar.pt
                    radius: 2 * bar.pt
                    color: bar.ink
                }
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 2 * bar.pt
                height: parent.height * 0.4
                radius: width / 2
                color: Qt.alpha(bar.ink, 0.4)
            }
        }
    }
}
