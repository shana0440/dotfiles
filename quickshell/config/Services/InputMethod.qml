pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// The current Fcitx input method, read from its tray icon, which carries engine and
// Mozc kana-mode changes (its tooltip title can be stale).
//
// Fcitx reports the state of the focused editor. While Quickshell holds the keyboard
// no editor is focused, so its icon falls back to English even though the editor
// keeps its input method. Meanwhile this keeps the last real state, and follows
// switches made while it is held, until Fcitx reports a change again.
Singleton {
    id: root

    // Set while a Quickshell surface holds the keyboard.
    property bool held: false
    readonly property var inputItem: SystemTray.items.values.find(item => item.id === "Fcitx") ?? null
    readonly property string trayIcon: inputItem?.icon.replace("image://icon/", "") ?? ""
    readonly property string icon: frozen ? heldIcon : trayIcon

    property bool frozen: false
    property string heldIcon: ""
    // Mozc keeps its kana mode across switches; show the last one seen.
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

    // Records a switch Fcitx applied to the editor while Quickshell held the keyboard.
    function selected(name) {
        if (frozen)
            heldIcon = iconOf(name)
    }

    // Fcitx applies the switch to the last focused editor.
    function select(name) {
        Quickshell.execDetached(["fcitx5-remote", "-s", name])
        selected(name)
    }

    // Fcitx's cycling hotkey never reaches it while Quickshell holds the keyboard.
    function next() {
        const index = order.indexOf(nameOf(icon))
        select(order[(index + 1) % order.length])
    }

    // The current group's input methods, in Fcitx's cycling order.
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

    // Hyprland's direct-selection shortcuts report here; see hyprland.lua.
    IpcHandler {
        target: "inputMethod"
        function selected(name: string): void { root.selected(name) }
    }
}
