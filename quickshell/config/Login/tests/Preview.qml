// Preview of the login/lock screen under plain Qt, the environment SDDM gives it.
//   qml Preview.qml -- [login|lock] [WALLPAPER]
// The password "test" succeeds; anything else fails.
import QtQuick
import QtQuick.Window
import ".."

Window {
    id: window

    readonly property var args: {
        const all = Qt.application.arguments
        const at = all.indexOf("--")
        return at < 0 ? [] : all.slice(at + 1)
    }
    readonly property var sessions: ["Hyprland", "Hyprland (uwsm-managed)"]
    property int session: 0

    width: 1707
    height: 960
    visible: true
    flags: Qt.FramelessWindowHint
    color: "black"
    title: "login-ui preview"

    HudScreen {
        id: screen
        anchors.fill: parent
        mode: window.args[0] === "login" ? "login" : "lock"
        wallpaper: window.args[1] ?? ""
        userName: "kwguo"
        hostName: "kwguo-nixos"
        sessionName: window.sessions[window.session]
        onSubmit: password => {
            authState = "busy"
            check.ok = password === "test"
            check.restart()
        }
        onEdited: if (authState === "denied") authState = "idle"
        onNextSession: window.session = (window.session + 1) % window.sessions.length
        Component.onCompleted: focusInput()
    }

    Timer {
        id: check
        property bool ok
        interval: 900
        onTriggered: {
            screen.authState = ok ? "granted" : "denied"
            if (ok) reset.restart()
        }
    }
    Timer {
        id: reset
        interval: 1500
        onTriggered: { screen.clear(); screen.authState = "idle" }
    }
}
