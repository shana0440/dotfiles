import QtQuick
import "../Components" as Components
import "../Services" as Services
import "../Theme" as Theme

Components.MergeableCircle {
    id: root

    signal clicked()
    Accessible.role: Accessible.Button
    Accessible.name: "Notifications: " + Services.Notifications.count
    activeFocusOnTab: !merged
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Components.Icon {
        anchors.centerIn: parent
        action: "notifications"
        width: 18
        height: 18
        iconColor: Services.Notifications.count > 0 ? Theme.Colors.accent : Theme.Colors.foreground
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        width: 7
        height: 7
        radius: 4
        color: Theme.Colors.accent
        visible: Services.Notifications.count > 0
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Components.Tooltip {
        text: "Notifications · " + Services.Notifications.count
        shown: mouse.containsMouse
    }
}
