import QtQuick
import "../Theme" as Theme

Surface {
    id: root

    property list<Item> views
    property Item activeView: null
    property Item overflowView: null
    property int alignment: Qt.AlignHCenter
    property real targetRadius: Math.min(16, targetHeight / 2)
    readonly property real targetWidth: activeView ? activeView.width : 0
    readonly property real targetHeight: activeView ? activeView.height : 0
    readonly property bool moving: widthSpring.moving || heightSpring.moving

    width: widthSpring.value
    height: heightSpring.value
    radius: Math.min(radiusSpring.value, height / 2)

    function moveTo(spring, target, anticipate) {
        const delta = target - spring.to
        const opening = delta > 0
        spring.stiffness = opening ? Theme.Motion.morphStiffness : Theme.Motion.closeStiffness
        spring.damping = opening ? Theme.Motion.morphDamping : Theme.Motion.closeDamping
        spring.to = target
        if (anticipate && Math.abs(delta) > 24)
            spring.impulse(opening ? Theme.Motion.anticipation : Theme.Motion.swell)
    }

    function kick(sideways, down) {
        shakeSpring.impulse(sideways)
        nudgeSpring.impulse(down)
    }
    readonly property point shift: Qt.point(shakeSpring.value, nudgeSpring.value)
    transform: Translate { x: root.shift.x; y: root.shift.y }

    onTargetWidthChanged: moveTo(widthSpring, targetWidth, true)
    onTargetHeightChanged: moveTo(heightSpring, targetHeight, false)
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
