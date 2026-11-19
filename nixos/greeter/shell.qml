import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import "Login" as Login

ShellRoot {
    id: root

    readonly property string userName: Quickshell.env("LOGIN_USER")
    readonly property var sessionCommand: [Quickshell.env("LOGIN_SESSION_COMMAND")]
    property string authState: "idle"
    property string message: ""
    property string pending: ""

    function submit(password) {
        if (authState === "busy" || authState === "granted") return
        pending = password
        authState = "busy"
        message = ""
        if (!Greetd.available) return fail("greetd is not running")
        Greetd.createSession(userName)
    }

    function fail(text) {
        pending = ""
        message = text
        authState = "denied"
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (!responseRequired) return
            if (root.pending.length) {
                Greetd.respond(root.pending)
                root.pending = ""
            } else {
                root.fail(message)
            }
        }
        function onAuthFailure(message) { root.fail("Wrong password") }
        function onError(error) { root.fail(error) }
        function onReadyToLaunch() {
            root.authState = "granted"
            Greetd.launch(root.sessionCommand)
        }
    }

    FileView {
        id: hostname
        path: "/etc/hostname"
        blockLoading: true
    }

    FloatingWindow {
        color: "black"

        Login.HudScreen {
            id: screen
            anchors.fill: parent
            mode: "login"
            userName: root.userName
            hostName: hostname.text().trim()
            authState: root.authState
            message: root.message
            wallpaper: Quickshell.env("LOGIN_WALLPAPER")
            sessionName: "Hyprland"
            sessionId: "hyprland"
            onSubmit: password => root.submit(password)
            onEdited: if (root.authState === "denied") root.authState = "idle"
            onSuspend: Quickshell.execDetached(["systemctl", "suspend"])
            onReboot: Quickshell.execDetached(["systemctl", "reboot"])
            onPowerOff: Quickshell.execDetached(["systemctl", "poweroff"])
            Component.onCompleted: focusInput()
        }
    }
}
