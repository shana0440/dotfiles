import QtQuick
import Quickshell
import "../Theme" as Theme
import "../Components" as Components

Rectangle {
    id: root

    property string iconSource: ""
    property string label: ""
    property bool active: false
    property bool badged: false
    property bool dimmed: false
    signal pressed(int button)

    width: 28
    height: parent ? parent.height : 24
    radius: 4
    color: active || mouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent

    Image {
        id: appIcon
        anchors.centerIn: parent
        width: 20
        height: 20
        opacity: root.dimmed ? 0.6 : 1
        source: root.iconSource
        sourceSize.width: width
        sourceSize.height: height
    }

    Text {
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        anchors.centerIn: parent
        visible: appIcon.status !== Image.Ready
        text: (root.label || "?").charAt(0).toUpperCase()
        color: Theme.Colors.foreground
        font.pixelSize: 14
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 10
        height: 2
        radius: 1
        color: Theme.Colors.foreground
        visible: root.active
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 1
        width: 7
        height: 7
        radius: width / 2
        color: Theme.Colors.info
        border.color: Theme.Colors.background
        border.width: 1
        visible: root.badged
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: event => root.pressed(event.button)
    }

    Components.Tooltip {
        shown: mouse.containsMouse
        delay: 500
        alignment: Qt.AlignHCenter
        text: root.label
    }
}
