import QtQuick
import "../Theme" as Theme

// The user's initial inside a dial: two outer arcs and a ring of ticks. The dial
// turns while a password is checked and takes the status color of the result.
Item {
    id: root

    property string initial: "?"
    property string authState: "idle"
    readonly property color tone: authState === "denied" ? Theme.Colors.error
        : authState === "granted" ? Theme.Colors.success
        : Theme.Colors.foreground

    implicitWidth: 132
    implicitHeight: 132

    Canvas {
        id: dial
        anchors.fill: parent
        property color tone: root.tone
        onToneChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            const c = width / 2
            ctx.reset()
            ctx.lineCap = "round"
            ctx.strokeStyle = tone
            ctx.globalAlpha = 0.85
            ctx.lineWidth = 2
            // Two arcs with gaps at the top-right and bottom-left.
            ctx.beginPath()
            ctx.arc(c, c, c - 2, Math.PI * 0.80, Math.PI * 1.45)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(c, c, c - 2, Math.PI * 1.80, Math.PI * 2.45)
            ctx.stroke()
            // Tick ring; every sixth tick is longer.
            ctx.globalAlpha = 0.45
            ctx.lineWidth = 1
            for (let i = 0; i < 60; i++) {
                const a = i / 60 * Math.PI * 2
                const outer = c - 10
                const inner = outer - (i % 6 === 0 ? 6 : 3)
                ctx.beginPath()
                ctx.moveTo(c + Math.cos(a) * inner, c + Math.sin(a) * inner)
                ctx.lineTo(c + Math.cos(a) * outer, c + Math.sin(a) * outer)
                ctx.stroke()
            }
        }

        RotationAnimator on rotation {
            from: 0; to: 360
            duration: 1400
            loops: Animation.Infinite
            running: root.authState === "busy"
            onRunningChanged: if (!running) dial.rotation = 0
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 40
        height: width
        radius: width / 2
        color: Theme.Colors.surface
        border.width: 1
        border.color: Theme.Colors.edge

        Text {
            anchors.centerIn: parent
            text: root.initial
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Font.Light
            font.pixelSize: 40
        }
    }
}
