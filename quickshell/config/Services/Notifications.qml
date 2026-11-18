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
    property bool previewClosing: false
    readonly property bool previewVisible: preview !== null || previewClosing
    property int previewCount: 1
    property int previewDuration: 0
    property bool previewPaused: false
    signal previewRestarted()
    signal previewRepeated()
    signal received()
    signal actionInvoked()
    property bool focusBlocked: false
    property var pendingSender: []
    property var afterFocusReturns: []

    function hidePreview() {
        previewTimer.stop()
        closeTimer.stop()
        previewPaused = false
        previewClosing = false
        preview = null
    }

    function dismissPreview() {
        if (!previewVisible || previewClosing)
            return
        previewTimer.stop()
        previewClosing = true
        closeTimer.restart()
    }

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

    function statusOf(notification) {
        if (notification.urgency === NotificationUrgency.Critical)
            return "error"
        return notification.desktopEntry === "screen-capture" ? "success" : "info"
    }

    function samePreview(a, b) {
        return a !== null && b !== null && a.appName === b.appName && a.summary === b.summary && a.body === b.body
    }

    function dismissAll() {
        const snapshotBeforeDismissMutatesModel = notifications.slice()
        snapshotBeforeDismissMutatesModel.forEach(notification => notification.dismiss())
    }

    function invokeAction(notification, action) {
        const senderReadBeforeInvokeDestroysNotification = [notification?.desktopEntry, notification?.appName].filter(name => name)
        action.invoke()
        pendingSender = senderReadBeforeInvokeDestroysNotification
        actionInvoked()
        if (!focusBlocked)
            Qt.callLater(flushFocus)
    }

    function whenFocusReturns(callback) {
        if (focusBlocked)
            afterFocusReturns = afterFocusReturns.concat([callback])
        else
            callback()
    }

    function flushFocus() {
        const names = pendingSender
        const callbacks = afterFocusReturns
        pendingSender = []
        afterFocusReturns = []
        focusSender(names)
        callbacks.forEach(callback => callback())
    }

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
            launchOnTheUsersWorkspace(entry)
    }

    function launchOnTheUsersWorkspace(entry) {
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

    Timer {
        id: closeTimer
        interval: 340
        onTriggered: root.hidePreview()
    }
}
