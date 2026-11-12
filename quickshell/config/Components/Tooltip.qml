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
    // The overlay covers the whole screen; place the owner layer surface on it from
    // its anchors and margins (full-screen surfaces such as the bar sit at 0,0).
    readonly property point ownerOrigin: {
        const window = root.ownerWindow
        const screen = window?.screen
        if (!screen || window.anchors === undefined)
            return Qt.point(0, 0)
        const anchors = window.anchors
        const margins = window.margins
        return Qt.point(
            anchors.left ? margins.left : anchors.right ? screen.width - window.width - margins.right
                : (screen.width - window.width) / 2,
            anchors.top ? margins.top : anchors.bottom ? screen.height - window.height - margins.bottom
                : (screen.height - window.height) / 2)
    }

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
            // mapToItem is not reactive; depending on `eligible` re-reads the
            // position each time the tooltip is shown, after layout has settled.
            readonly property point local: root.eligible && root.target && root.ownerWindow
                ? root.target.mapToItem(root.ownerWindow.contentItem, 0, 0) : Qt.point(0, 0)
            readonly property point position: Qt.point(root.ownerOrigin.x + local.x, root.ownerOrigin.y + local.y)
            readonly property real below: position.y + (root.target?.height ?? 0) + root.gap
            // Flip above targets near the bottom edge (e.g. the capture toolbar).
            readonly property bool fitsBelow: below + height <= parent.height
            readonly property real horizontalOffset: root.alignment === Qt.AlignRight
                ? (root.target?.width ?? 0) - width
                : root.alignment === Qt.AlignLeft ? 0 : ((root.target?.width ?? 0) - width) / 2

            x: Math.max(0, Math.min(parent.width - width, position.x + horizontalOffset))
            y: Math.max(0, Math.min(parent.height - height, fitsBelow ? below : position.y - root.gap - height))
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
