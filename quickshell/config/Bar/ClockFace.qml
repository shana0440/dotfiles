import QtQuick
import Quickshell
import "../Theme" as Theme

// An analog clock with the digital time and date beneath it.
Item {
    id: root

    property bool active: false
    readonly property date now: clock.date
    readonly property real hours: now.getHours() % 12 + now.getMinutes() / 60
    readonly property real minutes: now.getMinutes() + now.getSeconds() / 60

    implicitWidth: 200
    implicitHeight: 300

    SystemClock {
        id: clock
        enabled: root.active
        precision: SystemClock.Seconds
    }

    Item {
        id: face
        width: 152
        height: 152
        anchors.horizontalCenter: parent.horizontalCenter
        y: 32

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.Colors.surface
            border.width: 1
            border.color: Theme.Colors.ring
        }

        Repeater {
            model: 12

            Item {
                required property int index
                anchors.fill: parent
                rotation: index * 30

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    width: parent.index % 3 === 0 ? 3 : 2
                    height: parent.index % 3 === 0 ? 10 : 6
                    radius: width / 2
                    color: Theme.Colors.foreground
                    opacity: parent.index % 3 === 0 ? 0.9 : 0.35
                }
            }
        }

        component Hand: Rectangle {
            property real angle: 0
            property real length: 0
            x: (face.width - width) / 2
            y: face.height / 2 - length
            height: length
            radius: width / 2
            antialiasing: true
            transformOrigin: Item.Bottom
            rotation: angle
        }

        Hand {
            width: 4
            length: 40
            angle: root.hours * 30
            color: Theme.Colors.foreground
        }
        Hand {
            width: 3
            length: 58
            angle: root.minutes * 6
            color: Theme.Colors.foreground
        }
        Hand {
            width: 1.5
            length: 64
            angle: root.now.getSeconds() * 6
            color: Theme.Colors.muted
        }

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: Theme.Colors.foreground
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: face.bottom
        anchors.topMargin: 24
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "hh:mm:ss AP")
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 22
            font.features: ({ "tnum": 1 })
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            color: Theme.Colors.muted
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 12
        }
    }
}
