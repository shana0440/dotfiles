import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../Theme" as Theme
import "../Login" as Login

// The session lock: the shared login screen on every monitor, unlocked through PAM.
//   quickshell ipc call lock lock
// If Quickshell dies while locked, the compositor keeps the session locked.
Scope {
    id: root

    // idle | busy | denied | granted, shared by every monitor.
    property string authState: "idle"
    property string message: ""
    property string wallpaper: ""
    property string pending: ""
    // PAM service that checks the password; tests point it elsewhere.
    property string pamConfig: "hyprlock"
    property string pamDirectory: "/etc/pam.d"

    function lock() {
        if (sessionLock.locked) return
        authState = "idle"
        message = ""
        wallpaperQuery.running = true
        sessionLock.locked = true
    }

    function submit(password) {
        if (authState === "busy" || authState === "granted") return
        pending = password
        authState = "busy"
        message = ""
        if (!pam.start()) fail("Could not start authentication")
    }

    function fail(text) {
        pending = ""
        message = text
        authState = "denied"
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function locked(): bool { return sessionLock.locked }
    }

    PamContext {
        id: pam
        config: root.pamConfig
        configDirectory: root.pamDirectory
        user: Quickshell.env("USER")
        // pam_unix asks once for the password; any other prompt has no answer here.
        onPamMessage: {
            if (!responseRequired) return
            if (root.pending.length) {
                respond(root.pending)
                root.pending = ""
            } else {
                abort()
                root.fail(message)
            }
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.authState = "granted"
                unlockDelay.restart()
            } else {
                root.fail("Wrong password")
            }
        }
        onError: error => root.fail(PamError.toString(error))
    }

    // Long enough to see the result before the screen goes away.
    Timer {
        id: unlockDelay
        interval: 450
        onTriggered: sessionLock.locked = false
    }

    Process {
        id: wallpaperQuery
        command: ["awww", "query", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outputs = JSON.parse(text)[""] ?? []
                    root.wallpaper = outputs[0]?.displaying?.image ?? ""
                } catch (_) {}
            }
        }
    }

    FileView {
        id: hostname
        path: "/etc/hostname"
        blockLoading: true
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            color: Theme.Colors.background

            Login.HudScreen {
                id: screen
                anchors.fill: parent
                mode: "lock"
                userName: Quickshell.env("USER")
                hostName: hostname.text().trim()
                authState: root.authState
                message: root.message
                wallpaper: root.wallpaper
                onSubmit: password => root.submit(password)
                onEdited: if (root.authState === "denied") root.authState = "idle"
                onSuspend: Quickshell.execDetached(["systemctl", "suspend"])
                onReboot: Quickshell.execDetached(["systemctl", "reboot"])
                onPowerOff: Quickshell.execDetached(["systemctl", "poweroff"])
                Component.onCompleted: focusInput()

                Connections {
                    target: root
                    function onAuthStateChanged() {
                        if (root.authState === "granted") screen.clear()
                    }
                }
            }
        }
    }
}
