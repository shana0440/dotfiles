import QtQuick
import "../Theme" as Theme

Rectangle {
    id: root

    property bool playing: false
    property var levels: [0, 0, 0, 0, 0]
    property string tooltip: "Now playing"
    signal clicked()

    implicitWidth: 28
    implicitHeight: 28
    radius: 8
    color: mouse.containsMouse || activeFocus ? Theme.Colors.activeWorkspace : Theme.Colors.transparent
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: tooltip
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Row {
        anchors.centerIn: parent
        height: 20
        spacing: 2

        Repeater {
            model: 5

            Rectangle {
                id: bar
                required property int index

                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: root.playing ? Math.max(3, 20 * (root.levels[index] ?? 0)) : 3
                radius: 1.5
                color: Theme.Colors.accent

                Behavior on height {
                    SmoothedAnimation { velocity: 160 }
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Tooltip {
        text: root.tooltip
        shown: mouse.containsMouse || root.activeFocus
        alignment: Qt.AlignHCenter
    }
}
