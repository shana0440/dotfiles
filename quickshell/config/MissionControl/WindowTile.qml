import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme" as Theme

// One window in Mission Control: a live capture that moves from where the window
// sits (`frame`) to its place in the spread (`target`) as `progress` goes 0 → 1.
// It can be clicked to focus the window or dragged onto a workspace.
Item {
    id: root

    required property var toplevel
    required property var screenInfo
    property var frame: null
    property var target: null
    property real progress: 0
    // Once fully open, layout changes (a window leaving) glide instead of jumping.
    property bool settled: false
    property bool live: false
    property bool selected: false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool dragging: mouse.dragged

    signal clicked()
    signal dragMoved(real x, real y)
    signal dropped(real x, real y)

    property real targetX: target?.x ?? 0
    property real targetY: target?.y ?? 0
    property real targetWidth: target?.width ?? 0
    property real targetHeight: target?.height ?? 0
    Behavior on targetX { enabled: root.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on targetY { enabled: root.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on targetWidth { enabled: root.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on targetHeight { enabled: root.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    function lerp(a, b) { return a + (b - a) * progress }

    // While dragged the tile shrinks under the pointer so the strip stays visible.
    property real dragX: 0
    property real dragY: 0
    // Dropped on a workspace: stay where it was let go until the window leaves.
    property bool parked: false
    function resetDrag() { parked = false; dragX = 0; dragY = 0; mouse.dragged = false }
    onFrameChanged: if (!frame) resetDrag()
    onLiveChanged: if (!live) resetDrag()
    property real dragScale: dragging ? Math.min(1, 180 / Math.max(1, targetWidth)) : 1
    Behavior on dragScale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    visible: frame !== null && target !== null && live
    x: frame ? lerp(frame.x, targetX) + dragX : 0
    y: frame ? lerp(frame.y, targetY) + dragY : 0
    width: frame ? lerp(frame.width, targetWidth) : 0
    height: frame ? lerp(frame.height, targetHeight) : 0
    // The most recently focused window on top, as on the desktop; a dragged one above all.
    z: dragging ? 10000 : 1000 - (frame?.stack ?? 0)
    transformOrigin: Item.Center

    Item {
        id: body
        anchors.fill: parent
        scale: root.dragScale

        Rectangle {
            anchors.fill: parent
            visible: !capture.hasContent
            radius: 8
            color: Theme.Colors.surface
            border.color: Theme.Colors.ring
        }
        ScreencopyView {
            id: capture
            anchors.fill: parent
            captureSource: root.live ? root.toplevel.wayland : null
            live: true
            paintCursor: false
        }
        // Mission Control's selection ring sits just outside the window.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 10
            color: "transparent"
            border.width: 3
            border.color: Theme.Colors.foreground
            opacity: root.selected && root.progress > 0.9 && !root.dragging ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Rectangle {
            id: titlePill
            anchors { top: parent.bottom; topMargin: 10; horizontalCenter: parent.horizontalCenter }
            width: Math.min(titleText.implicitWidth + 22, Math.max(160, parent.width))
            height: titleText.implicitHeight + 10
            radius: height / 2
            color: Theme.Colors.panel
            opacity: root.selected && root.progress > 0.9 && !root.dragging ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Text {
                id: titleText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, titlePill.width - 22)
                text: root.toplevel.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.Colors.foreground
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 13
            }
        }
    }

    MouseArea {
        id: mouse
        property bool dragged: false
        property point pressAt
        anchors.fill: parent
        enabled: root.progress > 0.9
        hoverEnabled: true
        cursorShape: dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        // The tile moves with the drag, so track the pointer in window coordinates.
        onPressed: event => { pressAt = mapToItem(null, event.x, event.y); dragged = false }
        onPositionChanged: event => {
            if (!pressed) return
            const p = mapToItem(null, event.x, event.y)
            const dx = p.x - pressAt.x, dy = p.y - pressAt.y
            if (!dragged && Math.hypot(dx, dy) < 8) return
            dragged = true
            root.dragX = dx
            root.dragY = dy
            root.dragMoved(p.x, p.y)
        }
        onReleased: event => {
            if (!dragged) {
                root.clicked()
                return
            }
            const p = mapToItem(null, event.x, event.y)
            root.dropped(p.x, p.y)
            if (root.parked) return
            dragged = false
            root.dragX = 0
            root.dragY = 0
        }
    }
}
