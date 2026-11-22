import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../Components" as Components
import "../Theme" as Theme
import "../Services" as Services

PanelWindow {
    id: root

    readonly property int margin: 12
    readonly property int padding: 6
    readonly property int spacing: 4
    property int entriesRevision: 0

    function workspaceRank(toplevel) {
        const id = toplevel.workspace?.id ?? 0
        return id > 0 ? id : Number.MAX_SAFE_INTEGER + id
    }

    readonly property var apps: {
        const toplevels = Hyprland.toplevels.values
            .filter(toplevel => toplevel.wayland)
            .map((toplevel, opened) => {
                const [x, y] = toplevel.lastIpcObject?.at ?? [0, 0]
                return { toplevel, opened, x, y, rank: workspaceRank(toplevel) }
            })
            .sort((a, b) => a.rank - b.rank || a.x - b.x || a.y - b.y || a.opened - b.opened)
        const groups = []
        for (const { toplevel } of toplevels) {
            const window = toplevel.wayland
            const key = window.appId || window.title
            let group = groups.find(app => app.key === key)
            if (!group) {
                group = { key: key, windows: [], workspaces: [] }
                groups.push(group)
            }
            group.windows.push(window)
            group.workspaces.push(toplevel.workspace?.name ?? "")
        }
        return groups
    }

    readonly property var windowLayoutEvents: [
        "openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen",
        "togglegroup", "moveintogroup", "moveoutofgroup", "activespecialv2",
        "moveworkspacev2", "monitoraddedv2", "monitorremovedv2"
    ]

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.windowLayoutEvents.includes(event.name))
                windowLayoutRefresh.restart()
        }
    }

    Timer {
        id: windowLayoutRefresh
        interval: 100
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.entriesRevision++ }
    }

    function entryFor(appId) {
        root.entriesRevision
        return DesktopEntries.heuristicLookup(appId)
    }

    function activate(app) {
        const windows = app.windows
        const current = windows.findIndex(window => window.activated)
        windows[(current + 1) % windows.length].activate()
    }

    visible: apps.length > 0
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: dock.height + margin
    exclusiveZone: implicitHeight
    color: Theme.Colors.transparent
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-dock"
    mask: Region { item: dock }

    Components.Surface {
        id: dock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: widthSpring.value
        height: 44 + root.padding * 2
        radius: 16

        Components.Spring {
            id: widthSpring
            to: Math.min(row.implicitWidth, root.width - root.margin * 2) + root.padding * 2
            stiffness: Theme.Motion.morphStiffness
            damping: Theme.Motion.morphDamping
            Component.onCompleted: snap()
        }

        Item {
            anchors.fill: parent
            anchors.margins: root.padding
            clip: true

            Row {
                id: row
                spacing: root.spacing

                Repeater {
                    model: root.apps

                    DockButton {
                        required property var modelData
                        readonly property var entry: root.entryFor(modelData.key)

                        label: modelData.windows.length === 1
                            ? modelData.windows[0].title || entry?.name || modelData.key
                            : entry?.name || modelData.key
                        iconSource: Quickshell.iconPath(entry?.icon || "application-x-executable", true)
                        windowCount: modelData.windows.length
                        active: modelData.windows.some(window => window.activated)
                        badged: Services.LauncherBadges.hasUnread(modelData.key, entry?.id || "")
                        onClicked: root.activate(modelData)
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "dock"
        function state(): string {
            return JSON.stringify({
                apps: root.apps.map(app => ({
                    appId: app.key,
                    active: app.windows.some(window => window.activated),
                    windows: app.windows.map((window, index) => ({
                        title: window.title, workspace: app.workspaces[index], active: window.activated
                    }))
                }))
            })
        }
        function activate(appId: string): void {
            const app = root.apps.find(app => app.key === appId)
            if (app)
                root.activate(app)
        }
    }
}
