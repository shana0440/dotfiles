import QtQuick
import QtQuick.Shapes
import "../Theme" as Theme

// Ding's status glyphs: a ring plus one or two strokes on a 24×24 grid, drawn on like
// a pen line, each status with its own small gesture. Success pulses and ripples,
// error shakes its head, info pops its dot and draws its line.
Item {
    id: root

    // "success", "error" or "info".
    property string status: "info"
    property color color: Theme.Colors.status(status)

    implicitWidth: 22
    implicitHeight: 22

    readonly property var glyphs: ({
        success: [{ path: "M7.9 12.4l3 3 5.3-6" }],
        error: [{ path: "M9.3 9.3l5.4 5.4" }, { path: "M14.7 9.3l-5.4 5.4" }],
        info: [{ path: "M12 11v5.2" }, { path: "M12 7.8h.01", dot: true }]
    })[status] ?? []
    readonly property real strokeWidth: 2.2

    // A fresh icon waits for its ring to draw; a status change redraws only the glyph.
    property bool ready: false
    readonly property int glyphDelay: ready ? 50 : 550

    property real ringDrawn: 0
    property real firstDrawn: 0
    property real secondDrawn: 0
    property real dotScale: 1
    property real pulse: 1
    property real ripple: 0
    property real shake: 0
    property real pop: 1
    property real popOpacity: 1

    readonly property var drawCurve: [0.4, 0, 0.2, 1, 1, 1]
    readonly property list<Animation> gestures: [ringIn, arrive, popIn, drawFirst, drawFirstLate, drawSecond,
        pulseOut, rippleOut, shakeHead, popDot]

    function play() {
        for (const animation of gestures)
            animation.stop()
        firstDrawn = 0
        secondDrawn = 0
        dotScale = 1
        pulse = 1
        ripple = 0
        shake = 0

        if (ready) {
            popIn.start()
        } else {
            ringIn.start()
            arrive.start()
        }

        switch (status) {
        case "success":
            drawFirst.start()
            pulseOut.start()
            rippleOut.start()
            break
        case "error":
            drawFirst.start()
            drawSecond.start()
            shakeHead.start()
            break
        case "info":
            secondDrawn = 1
            popDot.start()
            drawFirstLate.start()
            break
        }
        readyTimer.restart()
    }

    // Replays the full arrival, ring included (an icon that is shown again).
    function restart() {
        readyTimer.stop()
        ready = false
        play()
    }

    onStatusChanged: play()
    Component.onCompleted: play()

    Timer {
        id: readyTimer
        interval: 900
        onTriggered: root.ready = true
    }

    SequentialAnimation {
        id: ringIn
        PropertyAction { target: root; property: "ringDrawn"; value: 0 }
        PauseAnimation { duration: 150 }
        NumberAnimation { target: root; property: "ringDrawn"; to: 1; duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: root.drawCurve }
    }
    // First arrival: grows from a quarter size (Ding's tst-swap).
    SequentialAnimation {
        id: arrive
        PropertyAction { target: root; property: "pop"; value: 0.25 }
        PropertyAction { target: root; property: "popOpacity"; value: 0 }
        PauseAnimation { duration: 100 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "pop"; to: 1; duration: 360; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popOpacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
        }
    }
    // A status change pops the icon in place.
    ParallelAnimation {
        id: popIn
        NumberAnimation { target: root; property: "pop"; from: 0.6; to: 1; duration: 360; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "popOpacity"; from: 0.3; to: 1; duration: 360; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: drawFirst
        PauseAnimation { duration: root.glyphDelay }
        NumberAnimation { target: root; property: "firstDrawn"; to: 1; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: root.drawCurve }
    }
    SequentialAnimation {
        id: drawFirstLate
        PauseAnimation { duration: root.glyphDelay + 160 }
        NumberAnimation { target: root; property: "firstDrawn"; to: 1; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: root.drawCurve }
    }
    SequentialAnimation {
        id: drawSecond
        PauseAnimation { duration: root.glyphDelay + 80 }
        NumberAnimation { target: root; property: "secondDrawn"; to: 1; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: root.drawCurve }
    }
    SequentialAnimation {
        id: pulseOut
        PauseAnimation { duration: root.glyphDelay + 250 }
        NumberAnimation { target: root; property: "pulse"; to: 1.14; duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "pulse"; to: 1; duration: 270; easing.type: Easing.OutBack }
    }
    SequentialAnimation {
        id: rippleOut
        PauseAnimation { duration: root.glyphDelay + 250 }
        NumberAnimation { target: root; property: "ripple"; from: 0; to: 1; duration: 700; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] }
        PropertyAction { target: root; property: "ripple"; value: 0 }
    }
    SequentialAnimation {
        id: shakeHead
        PauseAnimation { duration: root.glyphDelay + 300 }
        NumberAnimation { target: root; property: "shake"; to: -2.5; duration: 84 }
        NumberAnimation { target: root; property: "shake"; to: 2.5; duration: 105 }
        NumberAnimation { target: root; property: "shake"; to: -1.5; duration: 105 }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: 126 }
    }
    SequentialAnimation {
        id: popDot
        PropertyAction { target: root; property: "dotScale"; value: 0 }
        PauseAnimation { duration: root.glyphDelay }
        NumberAnimation { target: root; property: "dotScale"; to: 1; duration: 400; easing.type: Easing.OutBack }
    }

    // Drawn on the 24×24 grid and scaled to the icon size.
    Item {
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 22 * root.pop * root.pulse
        opacity: root.popOpacity
        transform: Translate { x: root.shake }

        // The success ripple: a thin ring that spreads and fades.
        Rectangle {
            anchors.centerIn: parent
            width: 22
            height: 22
            radius: 11
            color: "transparent"
            border.width: 1.5
            border.color: root.color
            visible: root.ripple > 0
            opacity: 0.55 * (1 - root.ripple)
            scale: 1 + 0.9 * root.ripple
        }

        // The ring, drawn counterclockwise from the top like Ding's. Trim does not cut a
        // closed path, so the arc's sweep does the drawing.
        Shape {
            anchors.fill: parent
            visible: root.ringDrawn > 0.001
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 12
                    centerY: 12
                    radiusX: 9
                    radiusY: 9
                    startAngle: -90
                    sweepAngle: -360 * root.ringDrawn
                }
            }
        }

        Repeater {
            model: root.glyphs

            Stroke {
                id: glyph
                required property var modelData
                required property int index
                anchors.fill: parent
                path: modelData.path
                drawn: index === 0 ? root.firstDrawn : root.secondDrawn
                // The dot pops about its own center.
                transform: Scale {
                    origin.x: 12
                    origin.y: 7.8
                    xScale: glyph.modelData.dot ? root.dotScale : 1
                    yScale: xScale
                }
            }
        }
    }

    // One stroke, drawn on from its start: `drawn` is the visible fraction.
    component Stroke: Shape {
        id: stroke
        property string path: ""
        property real drawn: 1
        visible: drawn > 0.001
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            // Ding draws with stroke-dashoffset on pathLength 1; trim is the same thing.
            trim.end: stroke.drawn
            PathSvg { path: stroke.path }
        }
    }
}
