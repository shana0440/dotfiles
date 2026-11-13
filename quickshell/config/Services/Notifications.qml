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
    // The popup collapses before it hides; it stays visible while closing, even if
    // the notification itself is already gone.
    property bool previewClosing: false
    readonly property bool previewVisible: preview !== null || previewClosing
    // Repeats of the popup's notification count up instead of replacing it.
    property int previewCount: 1
    // Lifetime of the popup in ms; 0 keeps it until dismissed.
    property int previewDuration: 0
    property bool previewPaused: false
    // Restarts the popup's countdown (a new notification or a repeat).
    signal previewRestarted()
    signal previewRepeated()
    signal received()
    // Menus holding exclusive keyboard focus must close so the compositor can focus the sender.
    signal actionInvoked()

    function hidePreview() {
        previewTimer.stop()
        closeTimer.stop()
        previewPaused = false
        previewClosing = false
        preview = null
    }

    // Collapse first, then hide (Ding's closing phase).
    function dismissPreview() {
        if (!previewVisible || previewClosing)
            return
        previewTimer.stop()
        previewClosing = true
        closeTimer.restart()
    }

    // Hovering the popup holds its countdown.
    function pausePreview(paused) {
        if (paused === previewPaused || previewClosing || previewDuration === 0)
            return
        previewPaused = paused
        if (paused) {
            previewTimer.remaining = Math.max(0, previewTimer.remaining - (Date.now() - previewTimer.startedAt))
            previewTimer.stop()
        } else {
            previewTimer.resume()
        }
    }

    function samePreview(a, b) {
        return a !== null && b !== null && a.appName === b.appName && a.summary === b.summary && a.body === b.body
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
            const repeat = !root.previewClosing && root.samePreview(root.preview, notification)
            root.previewCount = repeat ? root.previewCount + 1 : 1
            root.preview = notification
            closeTimer.stop()
            root.previewClosing = false
            root.previewPaused = false
            previewTimer.stop()
            // Expiry hides the popup, not the notification history.
            const sticky = notification.expireTimeout === 0 || notification.urgency === NotificationUrgency.Critical
            root.previewDuration = sticky ? 0 : notification.expireTimeout > 0 ? notification.expireTimeout : 5000
            if (!sticky) {
                previewTimer.remaining = root.previewDuration
                previewTimer.resume()
            }
            root.received()
            root.previewRestarted()
            if (repeat)
                root.previewRepeated()
        }
    }

    Connections {
        target: root.preview
        function onClosed() { root.dismissPreview() }
    }

    Timer {
        id: previewTimer
        property real remaining: 0
        property real startedAt: 0
        function resume() {
            startedAt = Date.now()
            interval = Math.max(1, remaining)
            start()
        }
        onTriggered: root.dismissPreview()
    }

    // Matches the toast's collapse: text erases and the pill shrinks back to its dot.
    Timer {
        id: closeTimer
        interval: 340
        onTriggered: root.hidePreview()
    }
}
