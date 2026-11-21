import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
    readonly property real buttonsWidth: buttonSize + (backgroundApps.length > 0 ? buttonSpacing + buttonSize : 0)
    readonly property real compactWidth: padding * 2 + buttonsWidth
    property bool soundOpen: false
    readonly property bool menuOpen: trayMenu.visible

    function openMenu(item) {
        trayMenu.open(item)
    }

    function backgroundIcon(item) {
        const themed = item.icon.match(/^image:\/\/icon\/([^?]+)$/)?.[1]
        if (!themed || Quickshell.iconPath(themed, true))
            return item.icon
        root.entriesRevision
        return Quickshell.iconPath(DesktopEntries.heuristicLookup(item.id)?.icon || "application-x-executable", true)
    }

    function openSound() {
        trayMenu.close()
        backgroundShown = false
        soundOpen = true
    }

    function pressBackgroundApp(item, mouseButton) {
        if (mouseButton === Qt.RightButton || (mouseButton === Qt.LeftButton && item.onlyMenu)) {
            if (item.hasMenu)
                root.openMenu(item)
        } else if (mouseButton === Qt.MiddleButton) {
            item.secondaryActivate()
        } else {
            item.activate()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "custom" && event.data === "pointerPressed" && root.showingBackground
                    && !islandHover.hovered && !trayMenu.hovered)
                root.backgroundShown = false
        }
    }

    HoverHandler { id: islandHover }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.entriesRevision++ }
    }

    alignment: Qt.AlignRight
    targetRadius: soundOpen ? 16 : islandHeight / 2
    activeView: soundOpen ? soundView : showingBackground ? backgroundView : compactView

    views: [
        Item {
            id: compactView
            width: root.compactWidth
            height: root.islandHeight
        },
        Item {
            id: backgroundView
            readonly property real stripWidth: Math.max(0, Math.min(backgroundStrip.contentWidth,
                root.availableWidth - root.compactWidth - root.buttonSpacing))
            width: root.compactWidth + root.buttonSpacing + stripWidth
            height: root.islandHeight

            AppStrip {
                id: backgroundStrip
                x: root.padding
                y: 4
                width: backgroundView.stripWidth
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
        },
        SoundView {
            id: soundView
            active: root.soundOpen
        }
    ]

    Row {
        z: 1
        opacity: root.soundOpen ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        anchors.right: parent.right
        anchors.rightMargin: root.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.buttonSpacing

        Components.IconButton {
            id: speaker
            implicitWidth: root.buttonSize
            implicitHeight: root.islandHeight - 8
            radius: 4
            iconSize: 18
            enabled: Services.Sound.audio !== null
            icon: Services.Sound.muted || Services.Sound.volume === 0 ? "speakerMuted"
                : Services.Sound.volume < 0.34 ? "speakerLow"
                : Services.Sound.volume < 0.67 ? "speakerMedium" : "speaker"
            tooltip: Services.Sound.muted ? "Muted" : "Volume " + Math.round(Services.Sound.volume * 100) + "%"
            onClicked: root.openSound()

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => Services.Sound.setVolume(Services.Sound.sink,
                    Services.Sound.volume + (event.angleDelta.y || event.angleDelta.x) / 120 * 0.05)
            }
        }

        Components.IconButton {
            visible: root.backgroundApps.length > 0
            implicitWidth: root.buttonSize
            implicitHeight: root.islandHeight - 8
            radius: 4
            iconSize: 18
            icon: "backgroundApps"
            selected: root.showingBackground
            tooltip: root.showingBackground ? "Hide background apps" : "Background apps"
            onClicked: root.backgroundShown = !root.showingBackground
        }
    }

    onShowingBackgroundChanged: if (!showingBackground) trayMenu.close()

    TrayMenu {
        id: trayMenu
        island: root
    }

    IpcHandler {
        target: "status"
        function showBackground(): void { root.backgroundShown = true }
        function hideBackground(): void { root.backgroundShown = false }
        function toggleBackground(): void { root.backgroundShown = !root.showingBackground }
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
            root.openMenu(item)
            return true
        }
        function closeMenu(): void { trayMenu.close() }
        function showSound(): void { root.openSound() }
        function hideSound(): void { root.soundOpen = false }
        function state(): string {
            return JSON.stringify({
                sound: root.soundOpen,
                background: {
                    shown: root.showingBackground,
                    menu: trayMenu.visible ? trayMenu.trayItem?.id ?? null : null,
                    apps: root.backgroundApps.map(item => ({
                        id: item.id, title: item.tooltipTitle || item.title,
                        status: ["passive", "active", "needsAttention"][item.status] ?? "active",
                        hasMenu: item.hasMenu
                    }))
                }
            })
        }
    }
}
