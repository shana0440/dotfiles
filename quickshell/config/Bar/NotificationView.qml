import QtQuick
import "../Components" as Components
import "../Services" as Services
import "../Theme" as Theme

Item {
    id: root

    property bool preview: false
    property int maximumHeight: 560
    readonly property var entries: preview
        ? (Services.Notifications.preview ? [Services.Notifications.preview] : [])
        : Services.Notifications.notifications.slice().reverse()
    signal closeRequested()
    signal listRequested()

    width: 420
    height: Math.min(maximumHeight, Math.max(144, cards.contentHeight + 64))

    Text {
        x: 16
        y: 15
        text: root.preview ? "New notification" : "Notifications · " + Services.Notifications.count
        color: Theme.Colors.foreground
        font.pixelSize: 14
        font.bold: true
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 4

        Components.IconButton {
            width: 28
            height: 28
            iconSize: 16
            icon: root.preview ? "notifications" : "clearNotifications"
            tooltip: root.preview ? "All notifications" : "Clear all notifications"
            enabled: root.preview || Services.Notifications.count > 0
            onClicked: {
                if (root.preview) root.listRequested()
                else Services.Notifications.dismissAll()
            }
        }

        Components.IconButton {
            width: 28
            height: 28
            iconSize: 16
            icon: "close"
            tooltip: "Close notifications"
            onClicked: root.closeRequested()
        }
    }

    ListView {
        id: cards
        anchors.fill: parent
        anchors.topMargin: 48
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 12
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: root.entries

        delegate: NotificationCard {
            required property var modelData
            width: cards.width
            notification: modelData
        }

        Text {
            anchors.centerIn: parent
            visible: cards.count === 0
            text: "No notifications"
            color: Theme.Colors.foreground
            opacity: 0.65
            font.pixelSize: 13
        }
    }
}
