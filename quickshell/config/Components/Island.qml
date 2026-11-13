import QtQuick
import QtQuick.Effects
import "../Theme" as Theme

// Keep views instantiated so subscriptions and pending requests survive view switches.
Rectangle {
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
    color: Theme.Colors.background

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
    Spring {
        id: radiusSpring
        to: root.targetRadius
        stiffness: Theme.Motion.morphStiffness
        damping: Theme.Motion.morphDamping
    }

    Item {
        anchors.fill: parent
        clip: root.activeView !== root.overflowView

        Repeater {
            model: root.views

            delegate: Item {
                id: viewContainer
                required property var modelData
                readonly property Item view: modelData
                readonly property bool current: root.activeView === view
                readonly property real reveal: revealSpring.value

                width: view.width
                height: view.height
                x: root.alignment === Qt.AlignRight ? parent.width - width
                    : root.alignment === Qt.AlignLeft ? 0 : (parent.width - width) / 2
                // Like Ding's text: content fades in, sharpens and settles into place.
                opacity: Math.max(0, Math.min(1, reveal * 1.5 - 0.25))
                visible: opacity > 0
                enabled: current
                transform: Translate { y: (1 - viewContainer.reveal) * -6 }

                // Blur only while it moves, so text at rest is never resampled.
                layer.enabled: visible && reveal < 0.995
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 16
                    blur: (1 - viewContainer.reveal) * 0.6
                }

                Spring {
                    id: revealSpring
                    to: viewContainer.current ? 1 : 0
                    stiffness: Theme.Motion.stackStiffness
                    damping: Theme.Motion.stackDamping
                    precision: 0.002
                }

                Component.onCompleted: view.parent = viewContainer
            }
        }
    }
}
