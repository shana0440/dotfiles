import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme" as Theme

// A separate overlay surface escapes both island clipping and the idle bar's bottom layer.
Item {
    id: root

    property Item target: parent
    property string text: ""
    property bool shown: false
    property int alignment: Qt.AlignRight
    property real gap: 8
    property int delay: 0
    readonly property var ownerWindow: root.target?.QsWindow.window ?? null
    readonly property bool eligible: root.shown && root.visible && root.ownerWindow !== null
        && root.target !== null && root.target.visible && root.target.enabled && root.text.length > 0

    Timer {
        id: showTimer
        interval: root.delay
        running: root.eligible && root.delay > 0
    }

    PanelWindow {
        id: overlay
        screen: root.ownerWindow?.screen ?? null
        visible: root.eligible && !showTimer.running
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell-tooltip"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Rectangle {
            readonly property point position: root.target && root.ownerWindow
                ? root.target.mapToItem(root.ownerWindow.contentItem, 0, root.target.height) : Qt.point(0, 0)
            readonly property real horizontalOffset: root.alignment === Qt.AlignRight
                ? (root.target?.width ?? 0) - width
                : root.alignment === Qt.AlignLeft ? 0 : ((root.target?.width ?? 0) - width) / 2

            x: Math.max(0, Math.min(parent.width - width, position.x + horizontalOffset))
            y: Math.max(0, Math.min(parent.height - height, position.y + root.gap))
            width: Math.min(label.implicitWidth + 16, parent.width)
            height: 26
            radius: 6
            color: Theme.Colors.background

            Text {
                id: label
                anchors.centerIn: parent
                width: parent.width - 16
                text: root.text
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                color: Theme.Colors.foreground
                font.pixelSize: 12
            }
        }
    }
}
