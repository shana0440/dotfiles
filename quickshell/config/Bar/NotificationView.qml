import QtQuick
import "../Components" as Components
import "../Services" as Services
import "../Theme" as Theme

Item {
    id: root

    property int maximumHeight: 560
    readonly property var entries: Services.Notifications.notifications.slice().reverse()
    signal closeRequested()

    width: 420
    height: Math.min(maximumHeight, Math.max(144, cards.contentHeight + 64))

    Row {
        x: 16
        y: 15
        spacing: 6

        Text {
            id: heading
            font.family: Theme.Fonts.family
            text: "Notifications"
            color: Theme.Colors.foreground
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text {
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            anchors.baseline: heading.baseline
            text: Services.Notifications.count
            color: Theme.Colors.foreground
            opacity: 0.7
            font.pixelSize: 12
            font.features: ({ "tnum": 1 })
        }
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 4

        Components.IconButton {
            width: 28
            height: 28
            radius: 14
            iconSize: 16
            icon: "clearNotifications"
            tooltip: "Clear all notifications"
            enabled: Services.Notifications.count > 0
            onClicked: Services.Notifications.dismissAll()
        }

        Components.IconButton {
            width: 28
            height: 28
            radius: 14
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
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            anchors.centerIn: parent
            visible: cards.count === 0
            text: "No notifications"
            color: Theme.Colors.foreground
            opacity: 0.65
            font.pixelSize: 13
        }
    }
}
