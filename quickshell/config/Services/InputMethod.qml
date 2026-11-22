pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Singleton {
    id: root

    property bool pickerOpen: false
    signal pickerStepped(int step)
    signal pickerActivated()
    readonly property var inputItem: SystemTray.items.values.find(item => item.id === "Fcitx") ?? null
    readonly property string trayIcon: inputItem?.icon.replace("image://icon/", "") ?? ""
    readonly property string icon: iconOf(name)

    property string name: "keyboard-us"
    property string mozcIcon: "fcitx_mozc_hiragana"
    property var order: ["keyboard-us", "mozc", "chewing"]

    onPickerOpenChanged: {
        if (pickerOpen)
            groupQuery.running = true
        else
            Qt.callLater(refreshCurrent)
    }
    Component.onCompleted: Qt.callLater(refreshCurrent)
    onTrayIconChanged: {
        if (trayIcon.startsWith("fcitx_mozc_"))
            mozcIcon = trayIcon
        if (!pickerOpen)
            Qt.callLater(refreshCurrent)
    }

    function iconOf(name) {
        return name === "mozc" ? mozcIcon
            : name === "chewing" ? "fcitx-chewing" : "input-keyboard-symbolic"
    }

    function selected(name, modeIcon) {
        if (modeIcon)
            mozcIcon = modeIcon
        root.name = name
    }

    function select(name) {
        Quickshell.execDetached(["fcitx5-remote", "-s", name])
        selected(name)
    }

    function next() {
        const index = order.indexOf(name)
        select(order[(index + 1) % order.length])
    }

    function refreshCurrent() {
        if (pickerOpen) return
        if (currentQuery.running)
            currentQuery.refreshPending = true
        else
            currentQuery.running = true
    }

    Process {
        id: currentQuery
        property bool refreshPending: false
        onRunningChanged: {
            if (!running && refreshPending) {
                refreshPending = false
                Qt.callLater(root.refreshCurrent)
            }
        }
        command: ["busctl", "--user", "--json=short", "call", "org.fcitx.Fcitx5",
            "/controller", "org.fcitx.Fcitx.Controller1", "CurrentInputMethod"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.pickerOpen)
                    return
                try {
                    const name = JSON.parse(text).data[0]
                    if (name)
                        root.name = name
                } catch (error) {}
            }
        }
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
