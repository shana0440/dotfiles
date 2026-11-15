import QtQuick
import QtQuick.Effects
import "../Theme" as Theme

Item {
    id: root

    property list<Item> views
    property Item activeView: null
    property int alignment: Qt.AlignHCenter

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
            x: root.alignment === Qt.AlignRight ? root.width - width
                : root.alignment === Qt.AlignLeft ? 0 : (root.width - width) / 2
            opacity: Math.max(0, Math.min(1, reveal * 1.5 - 0.25))
            visible: opacity > 0
            enabled: current
            transform: Translate { y: (1 - viewContainer.reveal) * -6 }

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
