import QtQuick
import "../Theme" as Theme
import "../Components" as Components

Rectangle {
    id: root

    property string iconSource: ""
    property string label: ""
    property int windowCount: 1
    property bool active: false
    property bool badged: false
    signal clicked

    width: 44
    height: 44
    radius: 10
    color: active || mouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent

    Image {
        id: appIcon
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        width: 32
        height: 32
        scale: mouse.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        source: root.iconSource
        sourceSize.width: width
        sourceSize.height: height
    }

    Text {
        anchors.centerIn: appIcon
        visible: appIcon.status !== Image.Ready
        text: (root.label || "?").charAt(0).toUpperCase()
        color: Theme.Colors.foreground
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        font.pixelSize: 20
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 3

        Repeater {
            model: Math.min(root.windowCount, 3)

            Rectangle {
                width: root.active ? 8 : 4
                height: 4
                radius: 2
                color: root.active ? Theme.Colors.foreground : Theme.Colors.muted
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 3
        width: 9
        height: 9
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
        onClicked: root.clicked()
    }

    Components.Tooltip {
        shown: mouse.containsMouse
        delay: 400
        alignment: Qt.AlignHCenter
        text: root.label
    }
}
