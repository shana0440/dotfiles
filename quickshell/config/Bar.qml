import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "Bar" as BarComponents
import "Components" as Components
import "Theme" as Theme
import "Services" as Services

PanelWindow {
    id: root

    readonly property int islandMargin: 20
    readonly property int compactIslandHeight: 32
    readonly property int islandSpacing: 8
    readonly property int reservedTopHeight: islandMargin + compactIslandHeight
    readonly property bool menuOpen: centerIsland.expanded
    readonly property bool soundOpen: statusIsland.soundOpen
    readonly property bool overlayOpen: menuOpen || soundOpen

    onSoundOpenChanged: if (soundOpen && centerIsland.expanded) centerIsland.close()
    readonly property bool menuNeedsKeyboardFocus: centerIsland.keyboardFocusRequired

    Binding {
        target: Services.InputMethod
        property: "pickerOpen"
        value: root.menuOpen && !root.menuNeedsKeyboardFocus
    }

    Binding {
        target: Theme.Colors
        property: "centerHeld"
        value: root.menuOpen || centerIsland.notificationVisible
    }

    function closeMenus() {
        statusIsland.soundOpen = false
        centerIsland.close()
    }

    Connections {
        target: Services.Notifications
        function onActionInvoked() {
            if (root.menuNeedsKeyboardFocus)
                Services.Notifications.focusBlocked = true
            root.closeMenus()
        }
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void {
            if (centerIsland.expanded)
                root.closeMenus()
            else
                root.openDashboard("home")
        }
        function open(tab: string): void { root.openDashboard(tab) }
        function close(): void { centerIsland.close() }
        function state(): string {
            return JSON.stringify({ open: centerIsland.expanded, tab: centerIsland.expandedView })
        }
    }

    function openDashboard(tab) {
        centerIsland.open(["home", "media", "notifications", "network", "settings", "system", "usage", "pomodoro", "power"].includes(tab) ? tab : "home")
    }

    Connections {
        target: Services.Bluetooth
        function onRequestChanged() {
            if (Services.Bluetooth.request)
                centerIsland.openBluetooth()
        }
    }

    IpcHandler {
        target: "inputMenu"
        function close() { root.closeMenus() }
        function next() { Services.InputMethod.pickerStepped(1) }
        function previous() { Services.InputMethod.pickerStepped(-1) }
        function activate() { Services.InputMethod.pickerActivated() }
    }

    onMenuNeedsKeyboardFocusChanged: {
        if (menuNeedsKeyboardFocus)
            grabKeyboard()
        else
            restoreLostWindowFocus.restart()
    }

    property bool keyboardUnfocused: false
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindowv2")
                root.keyboardUnfocused = event.data.length === 0
        }
    }

    Timer {
        id: restoreLostWindowFocus
        interval: 50
        onTriggered: {
            if (!Services.Capture.ownsInput && !root.menuNeedsKeyboardFocus && root.keyboardUnfocused)
                focusRestoringExclusiveLayer.visible = true
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
        id: focusRestoringExclusiveLayer
        screen: root.screen
        visible: false
        anchors.top: true
        anchors.left: true
        implicitWidth: 1
        implicitHeight: 1
        color: Theme.Colors.transparent
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Services.Capture.ownsInput ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-focus-relay"
        mask: Region {}

        onVisibleChanged: if (visible) relayRelease.restart()

        Timer {
            id: relayRelease
            interval: 50
            onTriggered: {
                focusRestoringExclusiveLayer.visible = false
                Qt.callLater(root.focusHandedBack)
            }
        }
    }

    onMenuOpenChanged: {
        if (menuOpen)
            statusIsland.soundOpen = false
        grabKeyboard()
    }
    function grabKeyboard() {
        Qt.callLater(() => {
            if (root.menuOpen && root.menuNeedsKeyboardFocus)
                centerIsland.focusSearch()
        })
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: Theme.Colors.transparent
    WlrLayershell.keyboardFocus: Services.Capture.ownsInput ? WlrKeyboardFocus.None
        : menuNeedsKeyboardFocus ? WlrKeyboardFocus.Exclusive
        : statusIsland.menuOpen || soundOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    readonly property bool showsAboveApps: overlayOpen || statusIsland.height > compactIslandHeight + 1 || centerIsland.notificationVisible || Services.Capture.recording
    WlrLayershell.layer: showsAboveApps ? WlrLayer.Overlay : WlrLayer.Bottom

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
        item: root.overlayOpen ? root.contentItem : workspaceIsland
        Region { item: appsIsland.visible ? appsIsland : null }
        Region { item: statusIsland }
        Region { item: centerIsland }
        Region { item: recordingStopIsland.visible ? recordingStopIsland : null }
        Region { item: mediaIsland.visible ? mediaIsland : null }
        Region { item: weatherIsland.visible ? weatherIsland : null }
        Region { item: notificationIsland.visible ? notificationIsland : null }
        Region { item: inputIsland.visible ? inputIsland : null }
    }

    Variants {
        id: otherMonitorDismissalSurfaces
        model: Quickshell.screens.filter(screen => screen !== root.screen)

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.overlayOpen
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
        enabled: root.overlayOpen
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
        Keys.onTabPressed: event => {
            if (centerIsland.expanded)
                centerIsland.moveFocus(true)
            else
                event.accepted = false
        }
        Keys.onBacktabPressed: event => {
            if (centerIsland.expanded)
                centerIsland.moveFocus(false)
            else
                event.accepted = false
        }
        Keys.onPressed: event => {
            if (centerIsland.expanded && (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)) {
                centerIsland.cycleTab(event.key === Qt.Key_PageDown ? 1 : -1)
                event.accepted = true
            } else if (root.menuNeedsKeyboardFocus && event.key === Qt.Key_Space
                    && (event.modifiers & ~Qt.KeypadModifier) === Qt.ControlModifier) {
                Services.InputMethod.next()
                event.accepted = true
            } else if (!(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                    && event.text.length > 0 && !/[\x00-\x1f\x7f]/.test(event.text)) {
                event.accepted = centerIsland.typeIntoSearch(event.text)
            }
        }

        TapHandler {
            enabled: root.overlayOpen
            acceptedButtons: Qt.AllButtons
            gesturePolicy: TapHandler.DragThreshold
            function containsBarPoint(item, position) {
                return item.visible && item.contains(item.mapFromItem(barContent, position.x, position.y))
            }

            onTapped: eventPoint => {
                const position = eventPoint.position
                const onCenterGroup = containsBarPoint(centerIsland, position)
                    || containsBarPoint(mediaIsland, position)
                    || containsBarPoint(weatherIsland, position)
                    || containsBarPoint(notificationIsland, position)
                    || containsBarPoint(inputIsland, position)
                if (centerIsland.expanded && !onCenterGroup)
                    centerIsland.close()
                if (root.soundOpen && !containsBarPoint(statusIsland, position))
                    statusIsland.soundOpen = false
            }
        }

        Components.IslandGoo {
            id: workspaceGoo
            target: workspaceIsland
            shaderSource: centerGoo
        }

        BarComponents.WorkspaceIsland {
            id: workspaceIsland
            bare: workspaceGoo.ready
            anchors.left: parent.left
            height: root.compactIslandHeight
        }

        Components.IslandGoo {
            id: statusGoo
            target: statusIsland
            leadingOuter: appsIsland
            shaderSource: centerGoo
        }

        BarComponents.AppsIsland {
            id: appsIsland
            bare: statusGoo.ready
            anchors.right: statusIsland.left
            anchors.rightMargin: offset
            gap: root.islandSpacing
            merged: statusIsland.soundOpen
            islandHeight: root.compactIslandHeight
            availableWidth: Math.max(0, statusIsland.x - root.islandSpacing * 2
                - Math.max(centerIsland.x + centerIsland.width,
                    recordingStopIsland.visible ? recordingStopIsland.x + recordingStopIsland.width : 0,
                    inputIsland.visible ? inputIsland.x + inputIsland.width : 0))
        }

        BarComponents.StatusIsland {
            id: statusIsland
            bare: statusGoo.ready
            anchors.right: parent.right
            islandHeight: root.compactIslandHeight
            availableWidth: Math.max(0, parent.width - root.islandSpacing
                - Math.max(centerIsland.x + centerIsland.width,
                    recordingStopIsland.visible ? recordingStopIsland.x + recordingStopIsland.width : 0,
                    inputIsland.visible ? inputIsland.x + inputIsland.width : 0))
        }

        Components.IslandGoo {
            id: centerGoo
            target: centerIsland
            leading: mediaIsland
            trailing: notificationIsland
            leadingOuter: weatherIsland
            trailingOuter: inputIsland
        }

        BarComponents.CenterIsland {
            id: centerIsland
            bare: centerGoo.ready
            clearness: Theme.Colors.centerClearness
            anchors.horizontalCenter: parent.horizontalCenter
            volumeShownElsewhere: statusIsland.soundOpen
            availableHeight: Math.min(560, Math.max(144, root.height - root.islandMargin * 2))
        }

        Components.IslandGoo {
            id: recordingStopGoo
            target: recordingStopIsland
            shaderSource: centerGoo
            z: 1
        }

        BarComponents.RecordingStopIsland {
            id: recordingStopIsland
            bare: recordingStopGoo.ready
            anchors.left: centerIsland.right
            anchors.leftMargin: root.islandSpacing
            height: root.compactIslandHeight
            width: height
            clearness: centerIsland.clearness
            visible: centerIsland.showingRecording
            stopping: Services.Capture.recordingCommandRunning
            onStopRequested: Services.Capture.stopRecording()
            z: 1
        }

        BarComponents.MediaIsland {
            id: mediaIsland
            bare: centerGoo.ready
            clearness: Theme.Colors.centerClearness
            anchors.right: centerIsland.left
            anchors.rightMargin: offset
            gap: root.islandSpacing
            outer: weatherIsland
            direction: -1
            merged: centerIsland.sideIslandsMerged
            onClicked: centerIsland.open("media")
        }

        BarComponents.WeatherIsland {
            id: weatherIsland
            bare: centerGoo.ready
            clearness: Theme.Colors.centerClearness
            anchors.right: mediaIsland.left
            anchors.rightMargin: offset
            gap: root.islandSpacing
            merged: centerIsland.sideIslandsMerged
            onClicked: centerIsland.open("home")
        }

        BarComponents.NotificationIsland {
            id: notificationIsland
            bare: centerGoo.ready
            clearness: Theme.Colors.centerClearness
            anchors.left: centerIsland.right
            anchors.leftMargin: offset
            gap: root.islandSpacing
            outer: inputIsland
            direction: 1
            merged: centerIsland.sideIslandsMerged
            onClicked: centerIsland.open("notifications")
        }

        BarComponents.InputIsland {
            id: inputIsland
            bare: centerGoo.ready
            clearness: Theme.Colors.centerClearness
            anchors.left: notificationIsland.right
            anchors.leftMargin: offset
            gap: root.islandSpacing
            merged: centerIsland.sideIslandsMerged
            onClicked: centerIsland.openInputMethods()
        }
    }
}
