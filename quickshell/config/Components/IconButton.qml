import QtQuick
import "../Theme" as Theme

Rectangle {
    id: root

    property string icon: ""
    property string tooltip: ""
    property color iconColor: Theme.Colors.foreground
    property bool highlighted: false
    signal clicked()

    implicitWidth: 36
    implicitHeight: 36
    radius: 8
    color: highlighted ? Theme.Colors.accent
        : mouse.containsMouse || activeFocus ? Theme.Colors.activeWorkspace : Theme.Colors.transparent
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: tooltip
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Icon {
        anchors.centerIn: parent
        action: root.icon
        iconColor: root.iconColor
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
