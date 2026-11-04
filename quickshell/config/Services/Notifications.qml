pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property var notifications: server.trackedNotifications.values
    readonly property int count: notifications.length
    property var preview: null
    readonly property bool previewVisible: preview !== null
    signal received()

    function hidePreview() {
        previewTimer.stop()
        preview = null
    }

    function dismissAll() {
        // Dismissing mutates the server model; iterate a snapshot.
        notifications.slice().forEach(notification => notification.dismiss())
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true
        bodyMarkupSupported: false
        imageSupported: false

        onNotification: notification => {
            notification.tracked = true
            root.preview = notification
            previewTimer.stop()
            // Expiry hides the popup, not the notification history.
            if (notification.expireTimeout !== 0 && notification.urgency !== NotificationUrgency.Critical) {
                previewTimer.interval = notification.expireTimeout > 0 ? notification.expireTimeout : 5000
                previewTimer.start()
            }
            root.received()
        }
    }

    Connections {
        target: root.preview
        function onClosed() { root.hidePreview() }
    }

    Timer {
        id: previewTimer
        onTriggered: root.hidePreview()
    }
}
