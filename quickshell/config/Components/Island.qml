import QtQuick
import "../Theme" as Theme

// Keep views instantiated so subscriptions and pending requests survive view switches.
Rectangle {
    id: root

    property list<Item> views
    property Item activeView: null
    property Item overflowView: null
    property int alignment: Qt.AlignHCenter
    property int resizeDuration: 260
    property int fadeDuration: 160

    width: activeView ? activeView.width : 0
    height: activeView ? activeView.height : 0
    radius: 8
    color: Theme.Colors.background

    Behavior on width {
        NumberAnimation { duration: root.resizeDuration; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: root.resizeDuration; easing.type: Easing.OutCubic }
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

                width: view.width
                height: view.height
                x: root.alignment === Qt.AlignRight ? parent.width - width
                    : root.alignment === Qt.AlignLeft ? 0 : (parent.width - width) / 2
                opacity: root.activeView === view ? 1 : 0
                visible: opacity > 0
                enabled: root.activeView === view

                Component.onCompleted: view.parent = viewContainer

                Behavior on opacity {
                    NumberAnimation { duration: root.fadeDuration; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
