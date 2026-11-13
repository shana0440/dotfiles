import QtQuick
import "../Theme" as Theme

// A side dot that slides under its neighbour while merged and pops back out on a
// spring, arriving from half size like a Ding toast.
Rectangle {
    id: root

    property bool merged: false
    property bool available: true
    property bool animateMerge: true
    // Distance to the neighbour when apart; anchor the circle with `offset`.
    property real gap: 8
    readonly property bool shown: available && !merged
    readonly property real offset: offsetSpring.value

    width: 32
    height: 32
    radius: height / 2
    color: Theme.Colors.background
    opacity: Math.max(0, Math.min(1, appearSpring.value * 2))
    scale: 0.5 + 0.5 * appearSpring.value
    visible: opacity > 0
    enabled: shown

    Spring {
        id: offsetSpring
        to: root.merged ? -root.width : root.gap
        enabled: root.animateMerge
        stiffness: root.merged ? Theme.Motion.closeStiffness : Theme.Motion.enterStiffness
        damping: root.merged ? Theme.Motion.closeDamping : Theme.Motion.enterDamping
    }

    Spring {
        id: appearSpring
        to: root.shown ? 1 : 0
        enabled: root.animateMerge
        stiffness: root.shown ? Theme.Motion.enterStiffness : Theme.Motion.closeStiffness
        damping: root.shown ? Theme.Motion.enterDamping : Theme.Motion.closeDamping
        precision: 0.002
    }
}
