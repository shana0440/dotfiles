import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme" as Theme
import "../Components" as Components

Scope {
    id: root

    property bool opened: false
    property string wallpaper: ""
    property int generation: 0

    function show() {
        if (opened) return
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
        wallpaperQuery.running = true
        generation++
        opened = true
    }
    function close() { opened = false }
    function dispatch(request) { Hyprland.dispatch(request) }
    function focusWindow(address) {
        dispatch("hl.dsp.focus({ window = \"address:0x" + address + "\" })")
    }
    function focusWorkspace(id) {
        dispatch("hl.dsp.focus({ workspace = " + id + " })")
        monitorRefresh.restart()
    }
    function moveWindow(address, workspaceId) {
        dispatch("hl.dsp.window.move({ workspace = " + workspaceId
            + ", window = \"address:0x" + address + "\", follow = false })")
        refresh.restart()
    }

    Timer {
        id: refresh
        interval: 120
        onTriggered: Hyprland.refreshToplevels()
    }

    Timer {
        id: monitorRefresh
        interval: 120
        onTriggered: Hyprland.refreshMonitors()
    }

    Process {
        id: wallpaperQuery
        command: ["awww", "query", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outputs = JSON.parse(text)[""] ?? []
                    root.wallpaper = outputs[0]?.displaying?.image ?? ""
                    root.wallpapers = Object.fromEntries(outputs.map(o => [o.name, o.displaying?.image ?? ""]))
                } catch (_) {}
            }
        }
    }
    property var wallpapers: ({})

    IpcHandler {
        target: "overview"
        function toggle(): void { if (root.opened) root.close(); else root.show() }
        function open(): void { root.show() }
        function close(): void { root.close() }
        function state(): string { return JSON.stringify({ open: root.opened }) }
    }

    Variants {
        model: Quickshell.screens

        MissionControlScreen {
            required property var modelData
            screenInfo: modelData
            controller: root
        }
    }
}
