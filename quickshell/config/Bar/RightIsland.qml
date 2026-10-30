import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Theme" as Theme
import "../Components" as Components

Rectangle {
    id: root

    property bool expanded: false
    readonly property bool confirming: expanded && menu.confirming

    width: expanded ? menu.implicitWidth : 40
    height: expanded ? menu.implicitHeight : 32
    radius: 8
    color: !expanded && powerMouse.containsMouse ? Theme.Colors.activeWorkspace : Theme.Colors.background

    function close() {
        expanded = false
        menu.cancel()
    }

    HyprlandFocusGrab {
        active: root.expanded
        windows: root.QsWindow.window ? [root.QsWindow.window] : []
        onCleared: root.close()
    }

    TapHandler {
        parent: root.parent
        enabled: root.expanded
        acceptedButtons: Qt.AllButtons
        gesturePolicy: TapHandler.DragThreshold
        onTapped: eventPoint => {
            const position = root.mapFromItem(parent, eventPoint.position.x, eventPoint.position.y)
            if (!root.contains(position))
                root.close()
        }
    }

    Components.Icon {
        anchors.centerIn: parent
        action: "poweroff"
        visible: !root.expanded
    }

    MouseArea {
        id: powerMouse
        anchors.fill: parent
        enabled: !root.expanded
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = true
    }

    PowerMenu {
        id: menu
        anchors.fill: parent
        visible: root.expanded
        onCloseRequested: root.close()
    }
}
