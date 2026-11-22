import QtQuick
import QtQuick.Effects
import "../Theme" as Theme

Item {
    id: root

    property Item view: null
    property bool current: false
    property int alignment: Qt.AlignHCenter
    readonly property real reveal: revealSpring.value

    width: view ? view.width : 0
    height: view ? view.height : 0
    x: alignment === Qt.AlignRight ? parent.width - width
        : alignment === Qt.AlignLeft ? 0 : (parent.width - width) / 2
    opacity: Math.max(0, Math.min(1, reveal * 1.5 - 0.25))
    visible: opacity > 0
    enabled: current
    transform: Translate { y: (1 - root.reveal) * -6 }

    layer.enabled: visible && reveal < 0.995
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 16
        blur: (1 - root.reveal) * 0.6
    }

    Spring {
        id: revealSpring
        to: root.current ? 1 : 0
        stiffness: Theme.Motion.stackStiffness
        damping: Theme.Motion.stackDamping
        precision: 0.002
    }
}
