import QtQuick
import "../Components" as Components
import "../Services" as Services
import "../Theme" as Theme

// The dashboard's notifications tab: the history, newest first.
Item {
    id: root

    property int maximumHeight: 560
    readonly property var entries: Services.Notifications.notifications.slice().reverse()
    readonly property int count: Services.Notifications.count

    width: 420
    height: Math.min(maximumHeight, cards.y + cards.contentHeight + 20)

    // The same header as the other tabs: title, a quiet line under it, one action.
    Item {
        id: header
        x: 20
        y: 20
        width: parent.width - 40
        height: 32

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: "Notifications"
                color: Theme.Colors.foreground
                font.family: Theme.Fonts.family
                font.pixelSize: 16
                font.bold: true
            }
            Text {
                text: root.count === 0 ? "No notifications" : root.count + (root.count === 1 ? " notification" : " notifications")
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 11
            }
        }
        Components.IconButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            iconSize: 16
            icon: "clearNotifications"
            tooltip: "Clear all"
            enabled: root.count > 0
            onClicked: Services.Notifications.dismissAll()
        }
    }

    ListView {
        id: cards
        x: 20
        y: header.y + header.height + 16
        width: parent.width - 40
        height: parent.height - y - 20
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: root.entries

        delegate: NotificationCard {
            required property var modelData
            width: cards.width
            notification: modelData
        }
    }
}
