import QtQuick

QtObject {
    id: root

    property real to: 0
    property real value: 0
    property real velocity: 0
    property real stiffness: 340
    property real damping: 27
    property real mass: 1
    property real precision: 0.05
    property bool enabled: true
    readonly property real longestStepAfterStalledFrame: 0.1
    readonly property bool moving: frames.running

    property bool _ready: false

    function snap() {
        frames.stop()
        velocity = 0
        value = to
    }

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
        onTriggered: root.step(Math.min(frameTime, root.longestStepAfterStalledFrame))
    }
}
