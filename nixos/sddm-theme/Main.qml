// SDDM greeter: the shared login/lock screen (quickshell/config/Login) wired to
// SDDM. nixos/login.nix copies Login, Theme and Icons next to this file.
import QtQuick
import "Login" as Login

Item {
    id: root

    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string authState: "idle"
    property string message: ""
    // userModel and sessionModel expose their rows only to delegates.
    readonly property string userName: userModel.lastUser || (users.count ? users.itemAt(0).name : "")

    Repeater {
        id: users
        model: userModel
        delegate: Item { readonly property string name: model.name }
    }
    Repeater {
        id: sessions
        model: sessionModel
        delegate: Item {
            readonly property string name: model.name
            readonly property string id: model.file.split("/").pop().replace(/\.desktop$/, "")
        }
    }
    readonly property Item session: sessions.count > sessionIndex ? sessions.itemAt(sessionIndex) : null

    Connections {
        target: sddm
        function onLoginFailed() {
            root.message = "Wrong password"
            root.authState = "denied"
        }
        function onLoginSucceeded() { root.authState = "granted" }
    }

    Login.HudScreen {
        id: screen
        anchors.fill: parent
        mode: "login"
        userName: root.userName
        hostName: sddm.hostName
        authState: root.authState
        message: root.message
        capsLock: keyboard.capsLock
        wallpaper: config.background || ""
        sessionName: root.session ? root.session.name : ""
        sessionId: root.session ? root.session.id : ""
        onSubmit: password => {
            root.authState = "busy"
            sddm.login(root.userName, password, root.sessionIndex)
        }
        onEdited: if (root.authState === "denied") root.authState = "idle"
        onNextSession: root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessions.count)
        onSuspend: if (sddm.canSuspend) sddm.suspend()
        onReboot: if (sddm.canReboot) sddm.reboot()
        onPowerOff: if (sddm.canPowerOff) sddm.powerOff()
        Component.onCompleted: focusInput()
    }
}
