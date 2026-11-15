import QtQuick
import "../Theme" as Theme

Surface {
    id: root

    property bool merged: false
    property bool available: true
    property bool animateMerge: true
    property real gap: 8
    property Item outer: null
    property int direction: -1
    property bool between: false
    readonly property bool shown: available && !merged
    readonly property real offset: offsetSpring.value
    readonly property real progress: (offset + width) / (gap + width)
    readonly property real drift: between ? direction * Math.max(0, 1 - progress) * (width + gap) / 2 : 0
    readonly property real diameter: visible ? width * scale : 0
    readonly property real paintedWidth: diameter
    readonly property real paintedHeight: visible ? height * scale : 0
    readonly property real paintedRadius: radius * scale
    readonly property real blend: height * smoothstep(0.15, 0.45, progress) * (1 - smoothstep(0.8, 1.1, progress))

    function smoothstep(from, to, value) {
        const t = Math.max(0, Math.min(1, (value - from) / (to - from)))
        return t * t * (3 - 2 * t)
    }

    width: 32
    height: 32
    radius: height / 2
    scale: between ? smoothstep(0.15, 0.8, progress) : 0.5 + 0.5 * smoothstep(0, 0.8, progress)
    transform: Translate { x: root.drift }
    onShownChanged: between = outer !== null && outer.available && !merged && outer.progress > 0.5
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
