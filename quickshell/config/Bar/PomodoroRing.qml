import QtQuick
import "../Theme" as Theme
import "../Services" as Services

// The center island's pomodoro badge: a ring of what is left of the phase around
// the minutes left, rounded up so the last minute reads 1.
Item {
    id: root

    readonly property real remainingFraction: Math.max(0, Math.min(1, 1 - Services.Pomodoro.progress))

    implicitWidth: 22
    implicitHeight: 22

    Canvas {
        id: ring
        anchors.fill: parent
        property real fraction: root.remainingFraction
        property color trackColor: Theme.Colors.track
        property color fillColor: Theme.Colors.foreground
        onFractionChanged: requestPaint()
        onTrackColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            const c = width / 2
            const r = c - 1.5
            ctx.reset()
            ctx.lineWidth = 2
            ctx.lineCap = "round"
            ctx.strokeStyle = trackColor
            ctx.beginPath()
            ctx.arc(c, c, r, 0, Math.PI * 2)
            ctx.stroke()
            if (fraction <= 0)
                return
            ctx.strokeStyle = fillColor
            ctx.beginPath()
            ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + fraction * Math.PI * 2)
            ctx.stroke()
        }
    }

    // Centers the digits' ink, not the line box, whose ascent and descent leave
    // the digits sitting high in the ring.
    TextMetrics {
        id: ink
        text: minutes.text
        font: minutes.font
    }

    Text {
        id: minutes
        x: root.width / 2 - (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2)
        y: root.height / 2 - baselineOffset - (ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2)
        text: Math.ceil(Services.Pomodoro.remaining / 60000)
        color: Theme.Colors.foreground
        font.family: Theme.Fonts.family
        font.weight: Font.DemiBold
        font.pixelSize: 10
        font.features: ({ "tnum": 1 })
    }
}
