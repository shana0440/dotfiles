import QtQuick
import "../Theme" as Theme

// A side dot that flows out of its neighbour while shown and back into it while
// hidden or merged. IslandGoo paints the liquid neck from `diameter` and `blend`.
Surface {
    id: root

    property bool merged: false
    property bool available: true
    property bool animateMerge: true
    // Distance to the neighbour when apart; anchor the circle with `offset`.
    property real gap: 8
    readonly property bool shown: available && !merged
    readonly property real offset: offsetSpring.value
    // 0 while buried in the neighbour, 1 at rest beside it; overshoots slightly.
    readonly property real progress: (offset + width) / (gap + width)
    // The painted circle: it shrinks to half size as it sinks into the neighbour.
    readonly property real diameter: visible ? width * scale : 0
    // Smooth-union radius for the goo. Zero while buried, so the neighbour does not
    // swell, and zero at rest, so the neck pinches off just before the dot settles.
    readonly property real blend: width * smoothstep(0.15, 0.45, progress) * (1 - smoothstep(0.8, 1.1, progress))

    function smoothstep(from, to, value) {
        const t = Math.max(0, Math.min(1, (value - from) / (to - from)))
        return t * t * (3 - 2 * t)
    }

    width: 32
    height: 32
    radius: height / 2
    scale: 0.5 + 0.5 * smoothstep(0, 0.8, progress)
    // Painted by IslandGoo, the shape stays solid and only the content fades; on
    // its own the whole surface fades.
    opacity: bare ? smoothstep(0.45, 0.85, progress) : Math.min(1, Math.max(0, progress * 2))
    visible: progress > 0.01
    enabled: shown

    Spring {
        id: offsetSpring
        to: root.shown ? root.gap : -root.width
        enabled: root.animateMerge
        stiffness: root.shown ? Theme.Motion.liquidStiffness : Theme.Motion.absorbStiffness
        damping: root.shown ? Theme.Motion.liquidDamping : Theme.Motion.absorbDamping
    }
}
