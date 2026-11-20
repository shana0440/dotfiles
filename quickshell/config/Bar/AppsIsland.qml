import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Components.Island {
    id: root

    property real availableWidth: 0
    property int islandHeight: 32
    property bool backgroundShown: false
    readonly property int buttonSize: 28
    readonly property int buttonSpacing: 4
    readonly property int padding: 8
    property int entriesRevision: 0
    readonly property var backgroundApps: SystemTray.items.values.filter(item => item.id !== "Fcitx")
    readonly property bool showingBackground: backgroundShown && backgroundApps.length > 0
    readonly property real toggleSlot: backgroundApps.length > 0 ? buttonSpacing + buttonSize : 0
    readonly property bool menuOpen: trayMenu.visible

    function stripWidth(contentWidth) {
        return Math.max(0, Math.min(contentWidth, availableWidth - padding * 2 - toggleSlot))
    }

    function backgroundIcon(item) {
        const themed = item.icon.match(/^image:\/\/icon\/([^?]+)$/)?.[1]
        if (!themed || Quickshell.iconPath(themed, true))
            return item.icon
        root.entriesRevision
        return Quickshell.iconPath(DesktopEntries.heuristicLookup(item.id)?.icon || "application-x-executable", true)
    }

    function showMenu(item) {
        if (item.hasMenu)
            trayMenu.open(item)
    }

    function pressBackgroundApp(item, mouseButton) {
        if (mouseButton === Qt.RightButton || (mouseButton === Qt.LeftButton && item.onlyMenu))
            showMenu(item)
        else if (mouseButton === Qt.MiddleButton)
            item.secondaryActivate()
        else
            item.activate()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.entriesRevision++ }
    }

    visible: (windows.count > 0 || backgroundApps.length > 0)
        && availableWidth >= buttonSize + padding * 2
    alignment: Qt.AlignRight
    targetRadius: islandHeight / 2
    activeView: showingBackground ? backgroundView : windowsView

    views: [
        Item {
            id: windowsView
            width: root.padding * 2 + root.toggleSlot + root.stripWidth(windowStrip.contentWidth)
                - (windows.count === 0 ? root.buttonSpacing : 0)
            height: root.islandHeight

            AppStrip {
                id: windowStrip
                x: root.padding
                y: 4
                width: root.stripWidth(contentWidth)
                height: parent.height - 8
                step: root.buttonSize + root.buttonSpacing

                Repeater {
                    id: windows
                    model: ToplevelManager.toplevels

                    AppButton {
                        id: windowButton
                        required property var modelData
                        readonly property var entry: {
                            root.entriesRevision
                            return DesktopEntries.heuristicLookup(modelData.appId)
                        }

                        label: modelData.title || entry?.name || modelData.appId || "Application"
                        iconSource: Quickshell.iconPath(entry?.icon || "application-x-executable", true)
                        active: modelData.activated
                        badged: Services.LauncherBadges.hasUnread(modelData.appId, entry?.id || "")
                        onPressed: mouseButton => {
                            if (mouseButton === Qt.LeftButton)
                                modelData.activate()
                        }

                        function revealIfActive() {
                            if (modelData.activated)
                                windowStrip.reveal(windowButton)
                        }
                        Component.onCompleted: Qt.callLater(revealIfActive)
                        Connections {
                            target: windowButton.modelData
                            function onActivatedChanged() { windowButton.revealIfActive() }
                        }
                    }
                }
            }
        },
        Item {
            id: backgroundView
            width: root.padding * 2 + root.toggleSlot + root.stripWidth(backgroundStrip.contentWidth)
            height: root.islandHeight

            AppStrip {
                id: backgroundStrip
                x: root.padding
                y: 4
                width: root.stripWidth(contentWidth)
                height: parent.height - 8
                step: root.buttonSize + root.buttonSpacing

                Repeater {
                    model: root.backgroundApps

                    AppButton {
                        required property SystemTrayItem modelData

                        label: modelData.tooltipTitle || modelData.title || modelData.id
                        iconSource: root.backgroundIcon(modelData)
                        badged: modelData.status === Status.NeedsAttention
                        dimmed: modelData.status === Status.Passive
                        onPressed: mouseButton => root.pressBackgroundApp(modelData, mouseButton)
                    }
                }
            }
        }
    ]

    Components.IconButton {
        z: 1
        visible: root.backgroundApps.length > 0
        anchors.right: parent.right
        anchors.rightMargin: root.padding
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.buttonSize
        implicitHeight: root.islandHeight - 8
        radius: 4
        iconSize: 18
        icon: root.showingBackground ? "window" : "backgroundApps"
        selected: root.showingBackground
        tooltip: root.showingBackground ? "Open windows" : "Background apps"
        onClicked: root.backgroundShown = !root.showingBackground
    }

    onShowingBackgroundChanged: if (!showingBackground) trayMenu.close()

    TrayMenu {
        id: trayMenu
        island: root
    }

    IpcHandler {
        target: "apps"
        function showWindows(): void { root.backgroundShown = false }
        function showBackground(): void { root.backgroundShown = true }
        function toggle(): void { root.backgroundShown = !root.showingBackground }
        function activate(id: string): bool {
            const item = root.backgroundApps.find(item => item.id === id)
            item?.activate()
            return item !== undefined
        }
        function openMenu(id: string): bool {
            const item = root.backgroundApps.find(item => item.id === id)
            if (!item?.hasMenu)
                return false
            root.backgroundShown = true
            trayMenu.open(item)
            return true
        }
        function closeMenu(): void { trayMenu.close() }
        function state(): string {
            return JSON.stringify({
                view: root.showingBackground ? "background" : "windows",
                menu: trayMenu.visible ? trayMenu.trayItem?.id ?? null : null,
                windows: ToplevelManager.toplevels.values.map(window => ({
                    appId: window.appId, title: window.title, active: window.activated
                })),
                background: root.backgroundApps.map(item => ({
                    id: item.id, title: item.tooltipTitle || item.title,
                    status: ["passive", "active", "needsAttention"][item.status] ?? "active",
                    hasMenu: item.hasMenu
                }))
            })
        }
    }
}
