import QtQuick
import "../Theme" as Theme

// A surface that springs to the size of its active view.
Surface {
    id: root

    property list<Item> views
    property Item activeView: null
    property Item overflowView: null
    property int alignment: Qt.AlignHCenter
    property real targetRadius: 8
    readonly property real targetWidth: activeView ? activeView.width : 0
    readonly property real targetHeight: activeView ? activeView.height : 0
    readonly property bool moving: widthSpring.moving || heightSpring.moving

    width: widthSpring.value
    height: heightSpring.value
    radius: Math.min(radiusSpring.value, height / 2)

    // Ding's morph: growing squeezes in a little and springs open; shrinking swells
    // first and settles on a firmer spring without overshoot. Small changes (a clock
    // tick) just glide.
    function moveTo(spring, target, anticipate) {
        const delta = target - spring.to
        const opening = delta > 0
        spring.stiffness = opening ? Theme.Motion.morphStiffness : Theme.Motion.closeStiffness
        spring.damping = opening ? Theme.Motion.morphDamping : Theme.Motion.closeDamping
        spring.to = target
        if (anticipate && Math.abs(delta) > 24)
            spring.impulse(opening ? Theme.Motion.anticipation : Theme.Motion.swell)
    }

    // Content-aware motion from Ding: a push that springs back to rest. An error
    // shakes its head (sideways on a loose spring), a repeat nudges it down.
    function kick(sideways, down) {
        shakeSpring.impulse(sideways)
        nudgeSpring.impulse(down)
    }
    transform: Translate { x: shakeSpring.value; y: nudgeSpring.value }

    onTargetWidthChanged: moveTo(widthSpring, targetWidth, true)
    onTargetHeightChanged: moveTo(heightSpring, targetHeight, false)
    // Change handlers skip the initial value; start at rest at the first size.
    Component.onCompleted: {
        widthSpring.to = targetWidth
        heightSpring.to = targetHeight
        widthSpring.snap()
        heightSpring.snap()
    }

    Spring { id: widthSpring }
    Spring { id: heightSpring }
    Spring { id: shakeSpring; stiffness: 520; damping: 13 }
    Spring {
        id: nudgeSpring
        stiffness: Theme.Motion.enterStiffness
        damping: Theme.Motion.enterDamping
    }
    Spring {
        id: radiusSpring
        to: root.targetRadius
        stiffness: Theme.Motion.morphStiffness
        damping: Theme.Motion.morphDamping
    }

    ViewStack {
        anchors.fill: parent
        clip: root.activeView !== root.overflowView
        views: root.views
        activeView: root.activeView
        alignment: root.alignment
    }
}
