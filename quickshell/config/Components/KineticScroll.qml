import QtQuick

WheelHandler {
    id: scroll

    required property Flickable view
    property real notch: 100
    property real velocity: 0
    property real lastSwipe: 0
    readonly property real topY: view.originY - view.topMargin
    readonly property real bottomY: Math.max(topY, view.originY + view.contentHeight + view.bottomMargin - view.height)
    readonly property real destination: glide.running ? glide.to : view.contentY

    signal headed(real y)
    signal glided

    function clampY(y) { return Math.max(topY, Math.min(bottomY, y)) }

    function glideBy(distance) {
        const to = clampY(destination + distance)
        glide.from = view.contentY
        glide.to = to
        headed(to)
        glide.restart()
    }

    function swipe(event) {
        const now = Date.now()
        const elapsed = Math.max(1, now - lastSwipe) / 1000
        const sample = event.pixelDelta.y / elapsed
        velocity = elapsed > 0.1 ? sample : velocity * 0.6 + sample * 0.4
        lastSwipe = now
        const to = clampY(view.contentY - event.pixelDelta.y)
        view.contentY = to
        headed(to)
    }

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        if (event.phase === Qt.ScrollEnd) {
            if (Date.now() - lastSwipe < 80) view.flick(0, velocity)
            velocity = 0
            return
        }
        view.cancelFlick()
        if (event.pixelDelta.y !== 0) {
            glide.stop()
            swipe(event)
        } else {
            glideBy(-event.angleDelta.y / 120 * notch)
        }
    }

    property NumberAnimation glide: NumberAnimation {
        target: scroll.view
        property: "contentY"
        duration: 220
        easing.type: Easing.OutCubic
        onFinished: scroll.glided()
    }
}
