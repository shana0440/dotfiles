pragma Singleton
import QtQuick

// Spring tunings from Ding (ding.yusufcengiz.dev), as stiffness / damping with mass 1.
QtObject {
    // Arrival: quick, lands with a hint of overshoot.
    readonly property real enterStiffness: 320
    readonly property real enterDamping: 26
    // Opening a surface: liquid but controlled.
    readonly property real morphStiffness: 340
    readonly property real morphDamping: 27
    // Closing: firmer, no overshoot.
    readonly property real closeStiffness: 380
    readonly property real closeDamping: 36
    // Content and small controls settling: tight, no wobble.
    readonly property real stackStiffness: 400
    readonly property real stackDamping: 36

    // Opening squeezes in first, closing swells first (px/s).
    readonly property real anticipation: -260
    readonly property real swell: 320
}
