import QtQuick
import "../Theme" as Theme
import "../Services" as Services

Row {
    id: root

    readonly property real remainingFraction: Math.max(0, Math.min(1, 1 - Services.Pomodoro.progress))

    spacing: 6

    Canvas {
        id: ring
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        property real fraction: root.remainingFraction
        property color trackColor: Theme.Colors.track
        property color fillColor: Theme.Colors.foreground
        onFractionChanged: requestPaint()
        onTrackColorChanged: requestPaint()
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

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Services.Pomodoro.format(Services.Pomodoro.remaining)
        color: Theme.Colors.foreground
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        font.pixelSize: 14
        font.features: ({ "tnum": 1 })
    }
}
