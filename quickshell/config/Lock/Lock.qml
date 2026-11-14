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
    property string pamConfig: "quickshell-lock"
    property string pamDirectory: "/etc/pam.d"
    // Lock: the background fades in over the desktop, then the card slides down.
    // Unlock: the card slides up, then the background fades out.
    // Hyprland's misc:session_lock_xray keeps the desktop drawn beneath it.
    property bool shown: false
    readonly property int fadeInDuration: 750
    readonly property int fadeOutDuration: 500
    readonly property int slideDuration: 480

    function lock() {
        if (sessionLock.locked) {
            // Locking again while it leaves: bring it back instead.
            if (!shown || unlockDelay.running) {
                unlockDelay.stop()
                authState = "idle"
                shown = true
            }
            return
        }
        // Without the PAM service no password could unlock it again.
        pamService.reload()
        if (!pamService.text().length) {
            console.warn("Lock: no PAM service at", pamService.path, "- not locking")
            return
        }
        authState = "idle"
        message = ""
        wallpaperQuery.running = true
        shown = true
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

    // Long enough to see the result before the sheet slides away.
    Timer {
        id: unlockDelay
        interval: 450
        onTriggered: root.shown = false
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
        id: pamService
        path: root.pamDirectory + "/" + root.pamConfig
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: hostname
        path: "/etc/hostname"
        blockLoading: true
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface
            color: Theme.Colors.transparent

            property real fade: 0
            property real cardIn: 0

            SequentialAnimation {
                id: enter
                NumberAnimation { target: surface; property: "fade"; to: 1; duration: root.fadeInDuration; easing.type: Easing.InOutQuad }
                NumberAnimation { target: surface; property: "cardIn"; to: 1; duration: root.slideDuration; easing.type: Easing.OutCubic }
            }

            // Still locked until the background is gone.
            SequentialAnimation {
                id: leave
                NumberAnimation { target: surface; property: "cardIn"; to: 0; duration: root.slideDuration; easing.type: Easing.InCubic }
                NumberAnimation { target: surface; property: "fade"; to: 0; duration: root.fadeOutDuration; easing.type: Easing.InOutQuad }
                onFinished: if (!root.shown) sessionLock.locked = false
            }

            Connections {
                target: root
                function onShownChanged() {
                    (root.shown ? leave : enter).stop();
                    (root.shown ? enter : leave).start()
                }
            }
            Component.onCompleted: if (root.shown) enter.start()

            Login.HudScreen {
                id: screen
                anchors.fill: parent
                opacity: surface.fade
                cardProgress: surface.cardIn
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
