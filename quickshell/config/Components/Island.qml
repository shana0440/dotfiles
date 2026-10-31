import QtQuick
import "../Theme" as Theme

// Views provide their own natural width/height; activeView selects one of them.
// All views stay instantiated so hiding a menu never stops its services/processes.
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
        // A compact status view may have tooltips extending beyond the island.
        clip: root.activeView !== root.overflowView

        Repeater {
            model: root.views

            delegate: Item {
                id: holder
                required property var modelData
                readonly property Item view: modelData

                width: view.width
                height: view.height
                x: root.alignment === Qt.AlignRight ? parent.width - width
                    : root.alignment === Qt.AlignLeft ? 0 : (parent.width - width) / 2
                opacity: root.activeView === view ? 1 : 0
                visible: opacity > 0
                enabled: root.activeView === view

                // Reparent once, rather than loading/unloading views on each switch.
                Component.onCompleted: view.parent = holder

                Behavior on opacity {
                    NumberAnimation { duration: root.fadeDuration; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
