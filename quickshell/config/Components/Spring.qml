import QtQuick

// A mass-spring-damper on one number, the motion model of Ding (ding.yusufcengiz.dev).
// Bind `to`, read `value`. Retargeting keeps the current velocity, so a move that is
// interrupted carries its momentum into the next one instead of restarting.
QtObject {
    id: root

    property real to: 0
    property real value: 0
    property real velocity: 0
    property real stiffness: 340
    property real damping: 27
    property real mass: 1
    // Rest threshold in the value's units; use a smaller one for 0..1 values.
    property real precision: 0.05
    // When false the value follows `to` immediately.
    property bool enabled: true
    readonly property bool moving: frames.running

    property bool _ready: false

    function snap() {
        frames.stop()
        velocity = 0
        value = to
    }

    // Adds speed without moving the target: a squeeze before opening, a swell before closing.
    function impulse(speed) {
        velocity += speed
        if (enabled)
            frames.start()
    }

    function step(dt) {
        const h = 1 / 240
        let x = value
        let v = velocity
        for (let t = 0; t < dt; t += h) {
            v += (-stiffness * (x - to) - damping * v) / mass * h
            x += v * h
        }
        if (Math.abs(v) < precision && Math.abs(x - to) < precision) {
            x = to
            v = 0
            frames.stop()
        }
        velocity = v
        value = x
    }

    onToChanged: {
        if (!_ready || !enabled)
            snap()
        else
            frames.start()
    }
    onEnabledChanged: if (!enabled) snap()

    Component.onCompleted: {
        value = to
        _ready = true
    }

    property FrameAnimation frames: FrameAnimation {
        // Cap long frames (a stalled compositor) so the spring never jumps past its target.
        onTriggered: root.step(Math.min(frameTime, 0.1))
    }
}
