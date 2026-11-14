import QtQuick
import QtQuick.Effects
import "../Theme" as Theme

// The login and lock screen, shared by the SDDM greeter and the Quickshell lock.
// Plain Qt Quick only: SDDM cannot load Quickshell modules. Wrappers set the
// inputs and act on the signals; this item only draws.
Item {
    id: root

    // "login" (SDDM) or "lock" (Quickshell).
    property string mode: "lock"
    property string userName: ""
    property string hostName: ""
    // idle | busy | denied | granted
    property string authState: "idle"
    property string message: ""
    property bool capsLock: false
    property string sessionName: ""
    property string sessionId: ""
    // Image path or URL; empty shows the plain background.
    property string wallpaper: ""

    signal submit(string password)
    signal edited()
    signal nextSession()
    signal suspend()
    signal reboot()
    signal powerOff()

    function focusInput() { card.focusInput() }
    function clear() { card.clear() }

    property date now: new Date()
    readonly property bool engaged: card.typing || authState !== "idle"

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // ---------------------------------------------------------------- background

    Rectangle { anchors.fill: parent; color: Theme.Colors.background }

    Image {
        id: wallpaperImage
        anchors.fill: parent
        source: root.wallpaper.length === 0 ? ""
            : root.wallpaper.indexOf("://") > 0 ? root.wallpaper : "file://" + root.wallpaper
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: width
        sourceSize.height: height
        asynchronous: true
        cache: false
        visible: false
    }

    // Blurred and dimmed; typing pulls it further back.
    MultiEffect {
        anchors.fill: parent
        source: wallpaperImage
        visible: wallpaperImage.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: root.engaged ? 1 : 0.55
        brightness: root.engaged ? -0.38 : -0.24
        saturation: -0.2
        Behavior on blur { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on brightness { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    }

    // Darker at the sides, where the clock and the card sit.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(Theme.Colors.background, 0.75) }
            GradientStop { position: 0.45; color: Qt.alpha(Theme.Colors.background, 0.15) }
            GradientStop { position: 0.6; color: Qt.alpha(Theme.Colors.background, 0.15) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.Colors.background, 0.7) }
        }
    }

    // Dot grid.
    Canvas {
        anchors.fill: parent
        opacity: 0.07
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = Theme.Colors.foreground
            const step = 40
            for (let x = step / 2; x < width; x += step)
                for (let y = step / 2; y < height; y += step)
                    ctx.fillRect(x - 1, y - 1, 2, 2)
        }
    }

    // A faint band drifting down the screen.
    Rectangle {
        id: sweep
        width: parent.width
        height: 120
        opacity: 0.035
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.Colors.transparent }
            GradientStop { position: 0.9; color: Theme.Colors.foreground }
            GradientStop { position: 1.0; color: Theme.Colors.transparent }
        }
        NumberAnimation on y {
            from: -sweep.height
            to: root.height
            duration: 11000
            loops: Animation.Infinite
        }
    }

    // ---------------------------------------------------------------- frame

    component Bracket: Canvas {
        property int dx: 1
        property int dy: 1
        width: 40
        height: 40
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = Theme.Colors.edge
            ctx.lineWidth = 2
            const x0 = dx > 0 ? 1 : width - 1
            const y0 = dy > 0 ? 1 : height - 1
            ctx.beginPath()
            ctx.moveTo(x0, y0 + dy * height)
            ctx.lineTo(x0, y0)
            ctx.lineTo(x0 + dx * width, y0)
            ctx.stroke()
        }
    }

    component Caption: Text {
        color: Theme.Colors.muted
        font.family: Theme.Fonts.mono
        font.pixelSize: 12
        font.letterSpacing: 2
    }

    readonly property int margin: 20
    Bracket { x: root.margin; y: root.margin }
    Bracket { x: root.width - width - root.margin; y: root.margin; dx: -1 }
    Bracket { x: root.margin; y: root.height - height - root.margin; dy: -1 }
    Bracket { x: root.width - width - root.margin; y: root.height - height - root.margin; dx: -1; dy: -1 }

    Row {
        x: 56
        y: 44
        spacing: 12
        Caption { text: root.hostName || root.userName; color: Theme.Colors.foreground }
        Caption { text: "//"; color: Theme.Colors.edge }
        Caption { text: root.mode === "login" ? "login" : "locked" }
    }

    Caption {
        anchors.right: parent.right
        anchors.rightMargin: 56
        y: 44
        text: Qt.formatTime(root.now, "HH:mm:ss")
        color: Theme.Colors.foreground
    }

    // ---------------------------------------------------------------- clock

    Column {
        id: clock
        x: Math.max(80, root.width * 0.065)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -40
        spacing: 0

        Row {
            spacing: 12
            Caption { text: "system time" }
            Caption { text: "//"; color: Theme.Colors.edge }
            Caption { text: Qt.formatDateTime(root.now, "t") }
        }

        Text {
            id: time
            text: Qt.formatTime(root.now, "HH:mm")
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Font.ExtraLight
            font.pixelSize: Math.min(200, root.height * 0.19)
            font.features: { "tnum": 1 }
            font.letterSpacing: -2
        }

        // Progress through the current minute.
        Item {
            width: time.width
            height: 3
            Rectangle { anchors.fill: parent; radius: 1.5; color: Theme.Colors.track }
            Rectangle {
                width: parent.width * root.now.getSeconds() / 59
                height: parent.height
                radius: 1.5
                color: Theme.Colors.foreground
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }

        Item { width: 1; height: 22 }

        Text {
            text: Qt.formatDate(root.now, "dddd · d MMMM yyyy")
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 22
            font.letterSpacing: 3
        }
    }

    // ---------------------------------------------------------------- card

    AuthCard {
        id: card
        anchors.right: parent.right
        anchors.rightMargin: Math.max(80, root.width * 0.065)
        anchors.verticalCenter: parent.verticalCenter
        mode: root.mode
        userName: root.userName
        hostName: root.hostName
        authState: root.authState
        message: root.message
        capsLock: root.capsLock
        sessionName: root.sessionName
        sessionId: root.sessionId
        onSubmit: password => root.submit(password)
        onEdited: root.edited()
        onNextSession: root.nextSession()
        onSuspend: root.suspend()
        onReboot: root.reboot()
        onPowerOff: root.powerOff()
    }

    Bracket { x: card.x - 12; y: card.y - 12; width: 28; height: 28 }
    Bracket { x: card.x + card.width - 16; y: card.y + card.height - 16; width: 28; height: 28; dx: -1; dy: -1 }

    // ---------------------------------------------------------------- ruler

    Item {
        id: ruler
        width: Math.min(900, root.width * 0.5)
        height: 40
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36

        Canvas {
            width: parent.width
            height: 14
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = Theme.Colors.edge
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(0, height - 0.5)
                ctx.lineTo(width, height - 0.5)
                for (let i = 0; i <= 60; i++) {
                    const x = Math.round(i / 60 * (width - 1)) + 0.5
                    ctx.moveTo(x, height)
                    ctx.lineTo(x, height - (i % 5 === 0 ? 10 : 5))
                }
                ctx.stroke()
            }

            // Marker at the current second.
            Text {
                x: parent.width * root.now.getSeconds() / 60 - width / 2
                y: -12
                text: "▾"
                color: Theme.Colors.foreground
                font.pixelSize: 10
                Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }

        Caption {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: ["hyprland", "quickshell", root.hostName].filter(part => part).join(" · ")
            font.pixelSize: 10
            font.letterSpacing: 3
        }
    }
}
