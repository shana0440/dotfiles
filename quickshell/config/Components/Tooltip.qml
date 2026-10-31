import QtQuick
import Quickshell
import "../Theme" as Theme

// Render in the window's overlay space, outside an island's clipping area.
Item {
    id: root

    property Item target: parent
    property string text: ""
    property bool shown: false
    property int alignment: Qt.AlignRight
    property real gap: 8

    Rectangle {
        parent: root.QsWindow.window?.contentItem ?? root
        readonly property point position: root.target
            ? root.target.mapToItem(parent, 0, root.target.height) : Qt.point(0, 0)
        readonly property real horizontalOffset: root.alignment === Qt.AlignRight
            ? (root.target?.width ?? 0) - width
            : root.alignment === Qt.AlignLeft ? 0 : ((root.target?.width ?? 0) - width) / 2

        x: Math.max(0, Math.min(parent.width - width, position.x + horizontalOffset))
        y: Math.max(0, Math.min(parent.height - height, position.y + root.gap))
        width: Math.min(label.implicitWidth + 16, parent.width)
        height: 26
        radius: 6
        color: Theme.Colors.background
        z: 100
        visible: root.shown && root.visible && root.target !== null
            && root.target.visible && root.target.enabled && root.text.length > 0

        Text {
            id: label
            anchors.centerIn: parent
            width: parent.width - 16
            text: root.text
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: Theme.Colors.foreground
            font.pixelSize: 12
        }
    }
}
