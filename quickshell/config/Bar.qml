import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "Bar" as BarComponents
import "Theme" as Theme
import "Services" as Services

PanelWindow {
    id: root

    readonly property int islandMargin: 20
    readonly property int compactIslandHeight: 32
    readonly property int islandSpacing: 8
    readonly property int reservedTopHeight: islandMargin + compactIslandHeight
    readonly property bool menuOpen: centerIsland.expanded || rightIsland.expanded
    readonly property bool menuNeedsKeyboardFocus: centerIsland.expanded || rightIsland.keyboardFocusRequired

    function closeMenus() {
        centerIsland.close()
        rightIsland.close()
    }

    Connections {
        target: Services.Notifications
        function onActionInvoked() {
            // Hyprland refuses window focus while an exclusive layer exists, so the
            // sender waits until the menu has handed the keyboard back.
            if (root.menuNeedsKeyboardFocus)
                Services.Notifications.focusBlocked = true
            root.closeMenus()
        }
    }

    // The expanded center island; it reopens on the last tab.
    IpcHandler {
        target: "dashboard"
        function toggle(): void {
            if (centerIsland.expanded)
                root.closeMenus()
            else
                root.openDashboard(centerIsland.expandedView)
        }
        function open(tab: string): void { root.openDashboard(tab) }
        function close(): void { centerIsland.close() }
    }

    function openDashboard(tab) {
        rightIsland.close()
        centerIsland.open(["calendar", "media", "notifications"].includes(tab) ? tab : "calendar")
    }

    IpcHandler {
        target: "inputMenu"
        function close() {
            if (rightIsland.mode === "input")
                rightIsland.close()
        }
    }

    // When a layer drops exclusive keyboard focus without unmapping, Hyprland clears
    // the focused surface but keeps the focused window, so its refocus of that window
    // is a no-op and the keyboard goes nowhere. Unmapping an exclusive layer takes the
    // working path, so a throwaway one hands focus back to the previous window.
    onMenuNeedsKeyboardFocusChanged: {
        if (!menuNeedsKeyboardFocus)
            focusCheck.restart()
    }

    // An empty activewindowv2 means no window has the keyboard.
    property bool keyboardUnfocused: false
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindowv2")
                root.keyboardUnfocused = event.data.length === 0
        }
    }

    Timer {
        id: focusCheck
        interval: 50
        onTriggered: {
            if (!root.menuNeedsKeyboardFocus && root.keyboardUnfocused)
                focusRelay.visible = true
            else
                root.focusHandedBack()
        }
    }

    function focusHandedBack() {
        if (Services.Notifications.focusBlocked) {
            Services.Notifications.focusBlocked = false
            Services.Notifications.flushFocus()
        }
    }

    PanelWindow {
        id: focusRelay
        screen: root.screen
        visible: false
        anchors.top: true
        anchors.left: true
        implicitWidth: 1
        implicitHeight: 1
        color: Theme.Colors.transparent
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-focus-relay"
        mask: Region {}

        onVisibleChanged: if (visible) relayRelease.restart()

        Timer {
            id: relayRelease
            interval: 50
            onTriggered: {
                focusRelay.visible = false
                Qt.callLater(root.focusHandedBack)
            }
        }
    }

    onMenuOpenChanged: {
        if (menuOpen) {
            Qt.callLater(() => {
                if (root.menuOpen && root.menuNeedsKeyboardFocus)
                    barContent.forceActiveFocus()
            })
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // A fixed native surface keeps window resizing from interrupting island animations.
    exclusionMode: ExclusionMode.Ignore
    color: Theme.Colors.transparent
    WlrLayershell.keyboardFocus: menuNeedsKeyboardFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Let overlapping floating windows cover the idle bar, but keep menus and alerts above apps.
    WlrLayershell.layer: menuOpen || centerIsland.notificationVisible || Services.Capture.recording
        ? WlrLayer.Overlay : WlrLayer.Bottom

    // Layer-shell infers the reservation edge from three-edge anchoring.
    PanelWindow {
        id: topReservation
        screen: root.screen
        visible: root.visible
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: root.reservedTopHeight
        exclusiveZone: root.reservedTopHeight
        color: Theme.Colors.transparent
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-reservation"
        mask: Region {}
    }

    mask: Region {
        item: root.menuOpen ? root.contentItem : workspaceIsland
        Region { item: appsIsland.visible ? appsIsland : null }
        Region { item: centerIsland }
        Region { item: mediaIsland.visible ? mediaIsland : null }
        Region { item: notificationIsland.visible ? notificationIsland : null }
        Region { item: rightIsland }
    }

    Variants {
        id: otherMonitorDismissalSurfaces
        model: Quickshell.screens.filter(screen => screen !== root.screen)

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.menuOpen
            color: Theme.Colors.transparent
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.closeMenus()
            }
        }
    }

    MouseArea {
        id: outsideClickArea
        anchors.fill: parent
        enabled: root.menuOpen
        acceptedButtons: Qt.AllButtons
        onPressed: root.closeMenus()
    }

    FocusScope {
        id: barContent
        anchors.fill: parent
        anchors.topMargin: root.islandMargin
        anchors.leftMargin: root.islandMargin
        anchors.rightMargin: root.islandMargin
        focus: true
        Keys.onEscapePressed: root.closeMenus()

        TapHandler {
            enabled: root.menuOpen
            acceptedButtons: Qt.AllButtons
            gesturePolicy: TapHandler.DragThreshold
            function containsBarPoint(item, position) {
                return item.visible && item.contains(item.mapFromItem(barContent, position.x, position.y))
            }

            onTapped: eventPoint => {
                const position = eventPoint.position
                const onCenterGroup = containsBarPoint(centerIsland, position)
                    || containsBarPoint(mediaIsland, position)
                    || containsBarPoint(notificationIsland, position)
                if (centerIsland.expanded && !onCenterGroup)
                    centerIsland.close()
                if (rightIsland.expanded && !containsBarPoint(rightIsland, position))
                    rightIsland.close()
            }
        }

        BarComponents.WorkspaceIsland {
            id: workspaceIsland
            anchors.left: parent.left
            height: root.compactIslandHeight
        }

        BarComponents.AppsIsland {
            id: appsIsland
            anchors.left: workspaceIsland.right
            anchors.leftMargin: root.islandSpacing
            height: root.compactIslandHeight
            availableWidth: Math.max(0, (mediaIsland.visible ? mediaIsland.x : centerIsland.x)
                - x - root.islandSpacing)
        }

        BarComponents.CenterIsland {
            id: centerIsland
            anchors.horizontalCenter: parent.horizontalCenter
            availableHeight: Math.min(560, Math.max(144, root.height - root.islandMargin * 2))
        }

        BarComponents.MediaIsland {
            id: mediaIsland
            anchors.right: centerIsland.left
            anchors.rightMargin: offset
            gap: root.islandSpacing
            merged: centerIsland.sideIslandsMerged
            onClicked: centerIsland.open("media")
        }

        BarComponents.NotificationIsland {
            id: notificationIsland
            anchors.left: centerIsland.right
            anchors.leftMargin: offset
            gap: root.islandSpacing
            merged: centerIsland.sideIslandsMerged
            onClicked: centerIsland.open("notifications")
        }

        BarComponents.RightIsland {
            id: rightIsland
            anchors.right: parent.right
            availableHeight: Math.max(200, root.height - root.islandMargin * 2)
        }
    }
}
