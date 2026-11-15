pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Singleton {
    id: root

    property bool held: false
    readonly property var inputItem: SystemTray.items.values.find(item => item.id === "Fcitx") ?? null
    readonly property string trayIcon: inputItem?.icon.replace("image://icon/", "") ?? ""
    readonly property string icon: frozen ? heldIcon : trayIcon

    property bool frozen: false
    property string heldIcon: ""
    property string mozcIcon: "fcitx_mozc_hiragana"
    property var order: ["keyboard-us", "mozc", "chewing"]

    onHeldChanged: {
        if (held) {
            heldIcon = trayIcon
            frozen = true
            groupQuery.running = true
        }
    }
    onTrayIconChanged: {
        if (trayIcon.startsWith("fcitx_mozc_"))
            mozcIcon = trayIcon
        if (!held)
            frozen = false
    }

    function nameOf(icon) {
        return icon.startsWith("fcitx_mozc") ? "mozc"
            : icon === "fcitx-chewing" ? "chewing" : "keyboard-us"
    }

    function iconOf(name) {
        return name === "mozc" ? mozcIcon
            : name === "chewing" ? "fcitx-chewing" : "input-keyboard-symbolic"
    }

    function selected(name) {
        if (frozen)
            heldIcon = iconOf(name)
    }

    function select(name) {
        Quickshell.execDetached(["fcitx5-remote", "-s", name])
        selected(name)
    }

    function next() {
        const index = order.indexOf(nameOf(icon))
        select(order[(index + 1) % order.length])
    }

    Process {
        id: groupQuery
        command: ["sh", "-c", "group=$(busctl --user call org.fcitx.Fcitx5 /controller "
            + "org.fcitx.Fcitx.Controller1 CurrentInputMethodGroup | cut -d'\"' -f2) && "
            + "busctl --user --json=short call org.fcitx.Fcitx5 /controller "
            + "org.fcitx.Fcitx.Controller1 InputMethodGroupInfo s \"$group\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const names = JSON.parse(text).data[1].map(entry => entry[0])
                    if (names.length > 0)
                        root.order = names
                } catch (error) {}
            }
        }
    }

    IpcHandler {
        target: "inputMethod"
        function selected(name: string): void { root.selected(name) }
    }
}
