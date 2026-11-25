import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Theme" as Theme

Scope {
    id: root

    property var addresses: []
    property string selected: ""
    property bool requested: false
    property bool opened: false

    readonly property var windows: addresses
        .map(address => Hyprland.toplevels.values.find(toplevel => toplevel.address === address))
        .filter(toplevel => toplevel)

    function show(index, list) {
        if (!requested) Hyprland.refreshToplevels()
        const shown = list.map(address => address.replace(/^0x/, ""))
        if (shown.join() !== addresses.join()) addresses = shown
        selected = shown[index - 1] ?? ""
        requested = true
        if (!opened) reveal.restart()
    }
    function select(address) {
        Hyprland.dispatch("function() windowSwitcher.select(\"0x" + address + "\") end")
    }
    function choose(address) {
        Hyprland.dispatch("function() windowSwitcher.choose(\"0x" + address + "\") end")
    }
    function close() {
        reveal.stop()
        requested = false
        opened = false
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "custom" || !event.data.startsWith("windowSwitcher ")) return
            const [, verb, index, ...list] = event.data.split(" ")
            if (verb === "show") root.show(Number(index), list)
            else root.close()
        }
    }

    Timer {
        id: reveal
        interval: 120
        onTriggered: root.opened = root.requested
    }

    IpcHandler {
        target: "windowSwitcher"
        function state(): string {
            return JSON.stringify({
                open: root.opened,
                selected: root.selected || null,
                windows: root.windows.map(window => ({
                    address: window.address,
                    class: window.lastIpcObject?.class ?? "",
                    title: window.title
                }))
            })
        }
    }

    Variants {
        model: Quickshell.screens

        WindowSwitcherScreen {
            required property var modelData
            screenInfo: modelData
            controller: root
        }
    }
}
