pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import Quickshell.Wayland

Singleton {
    id: root

    readonly property var notifications: server.trackedNotifications.values
    readonly property int count: notifications.length
    property var preview: null
    readonly property bool previewVisible: preview !== null
    signal received()
    // Menus holding exclusive keyboard focus must close so the compositor can focus the sender.
    signal actionInvoked()

    function hidePreview() {
        previewTimer.stop()
        preview = null
    }

    function dismissAll() {
        // Dismissing mutates the server model; iterate a snapshot.
        notifications.slice().forEach(notification => notification.dismiss())
    }

    function invokeAction(notification, action) {
        // Read the sender first: invoking may close and destroy the notification.
        const names = [notification?.desktopEntry, notification?.appName].filter(name => name)
        action.invoke()
        actionInvoked()
        // Wait for the closing menu to release its exclusive keyboard focus.
        Qt.callLater(() => focusSender(names))
    }

    // Hyprland ignores apps' own activation requests (focus_on_activate is off),
    // so the shell brings the sender forward itself, launching it if needed.
    function focusSender(names) {
        if (names.length === 0)
            return
        const wanted = names.map(name => name.toLowerCase())
        const entry = names.map(name => DesktopEntries.heuristicLookup(name)).find(found => found) ?? null
        const matches = toplevel => {
            const appId = (toplevel.appId || "").toLowerCase()
            if (appId.length === 0)
                return false
            if (wanted.includes(appId))
                return true
            const own = DesktopEntries.heuristicLookup(toplevel.appId)
            return entry !== null && own !== null && own.id === entry.id
        }
        const windows = ToplevelManager.toplevels.values.filter(matches)
        if (windows.some(toplevel => toplevel.activated))
            return
        if (windows.length > 0)
            windows[0].activate()
        else if (entry)
            launch(entry)
    }

    // Hyprland places windows from the shell's own process tree on the workspace the
    // shell started on; launching through the compositor opens them where the user is.
    function launch(entry) {
        if (entry.runInTerminal || entry.command.length === 0) {
            entry.execute()
            return
        }
        const shellQuote = arg => "'" + arg.replace(/'/g, "'\\''") + "'"
        let command = entry.command.map(shellQuote).join(" ")
        if (entry.workingDirectory)
            command = "cd " + shellQuote(entry.workingDirectory) + " && " + command
        Hyprland.dispatch("hl.dsp.exec_cmd(" + JSON.stringify(command) + ")")
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true
        bodyMarkupSupported: false
        imageSupported: true

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
