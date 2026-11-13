import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Layout.js" as Layout
import "../Theme" as Theme
import "../Components" as Components

// Mission Control on one monitor.
PanelWindow {
    id: win

    required property var screenInfo
    required property var controller

    readonly property var monitor: Hyprland.monitorFor(screenInfo)
    readonly property var activeWorkspace: monitor?.activeWorkspace ?? null
    readonly property bool focusedMonitor: Hyprland.focusedMonitor === monitor
    readonly property real progress: openSpring.value
    readonly property bool settled: controller.opened && !openSpring.moving

    // Workspaces of this monitor, in order; special workspaces stay hidden.
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(ws => ws.id > 0 && ws.monitor === monitor)
        .sort((a, b) => a.id - b.id)

    // Windows of a workspace, in this monitor's coordinates.
    function windowsOf(workspace) {
        return Hyprland.toplevels.values
            .filter(t => workspace && t.workspace === workspace && t.lastIpcObject?.at && !t.lastIpcObject.hidden)
            .map(t => ({
                address: t.address,
                x: t.lastIpcObject.at[0] - screenInfo.x,
                y: t.lastIpcObject.at[1] - screenInfo.y,
                width: Math.max(1, t.lastIpcObject.size[0]),
                height: Math.max(1, t.lastIpcObject.size[1]),
                stack: t.lastIpcObject.focusHistoryID ?? 0
            }))
    }
    // Spread rects by window address.
    function spreadOf(list) {
        const rects = Layout.spread(list, spreadArea, 28, 0.85)
        const byAddress = {}
        list.forEach((w, i) => byAddress[w.address] = rects[i])
        return byAddress
    }
    readonly property var windows: windowsOf(activeWorkspace)

    // Switching workspaces while open slides the spread sideways, like Spaces:
    // the old workspace's windows leave on one side as the new ones come in from
    // the other, by where the workspaces sit in the strip.
    property var shownWorkspace: null
    property var previousWorkspace: null
    property var previousSpread: ({})
    property int slideDirection: 1
    readonly property real slide: slideSpring.value
    readonly property bool sliding: slideSpring.moving
    onActiveWorkspaceChanged: {
        const from = shownWorkspace
        shownWorkspace = activeWorkspace
        if (!controller.opened || !from || !activeWorkspace || from === activeWorkspace) return
        previousWorkspace = from
        previousSpread = spreadOf(windowsOf(from))
        slideDirection = activeWorkspace.id > from.id ? 1 : -1
        selectedAddress = ""
        slideSpring.value = 0
        slideSpring.impulse(0)
    }

    readonly property real stripTop: 18
    readonly property real thumbHeight: Math.round(Math.min(130, height * 0.12))
    readonly property real thumbWidth: Math.round(thumbHeight * width / Math.max(1, height))
    readonly property real stripBottom: stripTop + thumbHeight + 30
    readonly property var spreadArea: ({
        x: 56, y: stripBottom + 28,
        width: width - 112, height: height - stripBottom - 28 - 56
    })
    readonly property var spread: spreadOf(windows)

    // Keyboard selection (index into `windows` order by layout), hover, and drag state.
    property string selectedAddress: ""
    property var dropTarget: null // a workspace id

    function chooseWindow(address) {
        controller.focusWindow(address)
        controller.close()
    }
    // Mission Control stays open on the new workspace.
    function chooseWorkspace(id) {
        controller.focusWorkspace(id)
    }
    function dropWindow(address, target) {
        if (target !== null) controller.moveWindow(address, target)
    }
    // The workspace drop target under a point in window coordinates.
    function targetAt(x, y) {
        for (let i = 0; i < thumbs.count; i++) {
            const item = thumbs.itemAt(i)
            const p = item.mapFromItem(win.contentItem, x, y)
            if (item.contains(p)) return item.workspaceId
        }
        return null
    }
    // Arrow keys move the selection to the nearest window in that direction.
    function moveSelection(dx, dy) {
        const rects = spread
        const current = rects[selectedAddress]
        const addresses = Object.keys(rects)
        if (!addresses.length) return
        if (!current) { selectedAddress = addresses[0]; return }
        const cx = current.x + current.width / 2, cy = current.y + current.height / 2
        let best = null, bestScore = Infinity
        for (const address of addresses) {
            const r = rects[address]
            const ox = r.x + r.width / 2 - cx, oy = r.y + r.height / 2 - cy
            const along = ox * dx + oy * dy
            if (along <= 1) continue
            const score = along + Math.abs(ox * dy + oy * dx) * 2
            if (score < bestScore) { bestScore = score; best = address }
        }
        if (best) selectedAddress = best
    }

    screen: screenInfo
    visible: controller.opened || progress > 0.002
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-overview"
    WlrLayershell.keyboardFocus: controller.opened && focusedMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Components.Spring {
        id: openSpring
        to: win.controller.opened ? 1 : 0
        stiffness: win.controller.opened ? Theme.Motion.morphStiffness : Theme.Motion.closeStiffness
        damping: win.controller.opened ? Theme.Motion.morphDamping : Theme.Motion.closeDamping
        precision: 0.001
    }
    Components.Spring {
        id: slideSpring
        to: 1
        // Critically damped and a little slower than the other motion, like Spaces.
        stiffness: 220
        damping: 30
        precision: 0.001
    }

    Connections {
        target: win.controller
        function onOpenedChanged() {
            win.dropTarget = null
            if (win.controller.opened) {
                win.shownWorkspace = win.activeWorkspace
                win.previousWorkspace = null
                slideSpring.snap()
                const active = Hyprland.activeToplevel
                win.selectedAddress = active && win.spread[active.address] ? active.address : ""
                stage.forceActiveFocus()
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.controller.close()
        Keys.onLeftPressed: win.moveSelection(-1, 0)
        Keys.onRightPressed: win.moveSelection(1, 0)
        Keys.onUpPressed: win.moveSelection(0, -1)
        Keys.onDownPressed: win.moveSelection(0, 1)
        Keys.onReturnPressed: if (win.spread[win.selectedAddress]) win.chooseWindow(win.selectedAddress)
        Keys.onEnterPressed: if (win.spread[win.selectedAddress]) win.chooseWindow(win.selectedAddress)
        Keys.onPressed: event => {
            const n = event.key - Qt.Key_0
            if (n >= 1 && n <= 9 && win.workspaces[n - 1]) {
                win.chooseWorkspace(win.workspaces[n - 1].id)
                event.accepted = true
            }
        }

        // The desktop behind the windows, softened and dimmed as Mission Control opens.
        Image {
            id: backdrop
            anchors.fill: parent
            source: win.controller.wallpapers[win.screenInfo.name] || win.controller.wallpaper
                ? "file://" + (win.controller.wallpapers[win.screenInfo.name] || win.controller.wallpaper) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 1280
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: backdrop
            visible: backdrop.status === Image.Ready
            blurEnabled: true
            blurMax: 48
            // No padding: the blur clamps at the screen edges instead of fading to black.
            autoPaddingEnabled: false
            blur: 0.8 * win.progress
            opacity: Math.min(1, win.progress * 4)
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.Colors.background
            opacity: backdrop.status === Image.Ready ? 0.35 * win.progress : 0.85 * win.progress
        }
        MouseArea {
            anchors.fill: parent
            onClicked: win.controller.close()
        }

        // Workspaces strip.
        Item {
            id: strip
            width: parent.width
            height: win.stripBottom
            y: -height * (1 - win.progress)
            opacity: win.progress

            Row {
                id: spaces
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.stripTop
                spacing: 20

                Repeater {
                    id: thumbs
                    model: win.workspaces

                    WorkspaceThumb {
                        required property var modelData
                        workspace: modelData
                        workspaceId: modelData.id
                        width: win.thumbWidth
                        height: win.thumbHeight + 26
                        thumbHeight: win.thumbHeight
                        screenInfo: win.screenInfo
                        wallpaper: backdrop.source
                        live: win.controller.opened
                        generation: win.controller.generation
                        current: modelData === win.activeWorkspace
                        dropping: win.dropTarget === modelData.id
                        onClicked: win.chooseWorkspace(modelData.id)
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: win.windows.length === 0
            opacity: win.progress * win.slide
            text: "No windows on this workspace"
            color: Theme.Colors.muted
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 15
        }

        // Windows of the active workspace, morphing from where they sit to the spread,
        // and during a switch those of the workspace being left.
        Repeater {
            model: Hyprland.toplevels

            WindowTile {
                id: tile
                required property var modelData
                toplevel: modelData
                screenInfo: win.screenInfo
                readonly property bool current: modelData.workspace === win.activeWorkspace
                    && !!win.spread[modelData.address]
                readonly property bool leaving: !current && win.sliding
                    && modelData.workspace === win.previousWorkspace && !!win.previousSpread[modelData.address]
                frame: current ? win.windows.find(w => w.address === modelData.address) ?? null : null
                target: current ? win.spread[modelData.address] : leaving ? win.previousSpread[modelData.address] : null
                slot: current ? "current" : leaving ? "leaving" : ""
                offsetX: current ? win.slideDirection * win.width * (1 - win.slide)
                    : leaving ? -win.slideDirection * win.width * win.slide : 0
                progress: win.progress
                settled: win.settled
                live: win.controller.opened || win.progress > 0.002
                selected: win.selectedAddress === modelData.address
                onHoveredChanged: if (hovered) win.selectedAddress = modelData.address
                onClicked: win.chooseWindow(modelData.address)
                onDragMoved: (x, y) => win.dropTarget = win.targetAt(x, y)
                onDropped: (x, y) => {
                    const target = win.targetAt(x, y)
                    tile.parked = target !== null
                    win.dropWindow(modelData.address, target)
                    win.dropTarget = null
                }
            }
        }
    }
}
