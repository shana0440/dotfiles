import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    required property var toplevel
    required property var screenInfo
    property var frame: null
    property var target: null
    property string slot: ""
    property real offsetX: 0
    property real progress: 0
    property bool settled: false
    property bool live: false
    property bool selected: false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool dragging: mouse.dragged

    signal clicked()
    signal dragMoved(real x, real y)
    signal dropped(real x, real y)
    signal dragCanceled()

    readonly property real targetX: springX.value
    readonly property real targetY: springY.value
    readonly property real targetWidth: springWidth.value
    readonly property real targetHeight: springHeight.value
    Components.Spring { id: springX; to: root.target?.x ?? 0; enabled: root.settled; stiffness: Theme.Motion.stackStiffness; damping: Theme.Motion.stackDamping }
    Components.Spring { id: springY; to: root.target?.y ?? 0; enabled: root.settled; stiffness: Theme.Motion.stackStiffness; damping: Theme.Motion.stackDamping }
    Components.Spring { id: springWidth; to: root.target?.width ?? 0; enabled: root.settled; stiffness: Theme.Motion.stackStiffness; damping: Theme.Motion.stackDamping }
    Components.Spring { id: springHeight; to: root.target?.height ?? 0; enabled: root.settled; stiffness: Theme.Motion.stackStiffness; damping: Theme.Motion.stackDamping }
    function snapTarget() { springX.snap(); springY.snap(); springWidth.snap(); springHeight.snap() }
    onSlotChanged: { snapTarget(); Qt.callLater(snapTarget) }

    function lerp(a, b) { return a + (b - a) * progress }

    property point dragPosition
    property point grabFraction
    property bool parked: false
    function resetDrag() {
        const canceled = dragging && !parked
        parked = false
        mouse.dragged = false
        if (canceled) dragCanceled()
    }
    onFrameChanged: if (!frame) resetDrag()
    onLiveChanged: if (!live) resetDrag()
    property real dragScale: dragging ? Math.min(1, 180 / Math.max(1, targetWidth)) : 1
    Behavior on dragScale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    visible: target !== null && live
    x: dragging ? dragPosition.x - width * (0.5 + (grabFraction.x - 0.5) * dragScale)
        : (frame ? lerp(frame.x, targetX) : targetX) + offsetX
    y: dragging ? dragPosition.y - height * (0.5 + (grabFraction.y - 0.5) * dragScale)
        : (frame ? lerp(frame.y, targetY) : targetY)
    width: frame ? lerp(frame.width, targetWidth) : targetWidth
    height: frame ? lerp(frame.height, targetHeight) : targetHeight
    z: dragging ? 10000 : 1000 - (frame?.stack ?? 0)

    Item {
        id: body
        anchors.fill: parent
        transformOrigin: Item.Center
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
        onPressed: event => {
            if (root.parked) { event.accepted = false; return }
            pressAt = mapToItem(null, event.x, event.y)
            const grab = mapToItem(body, event.x, event.y)
            root.grabFraction = Qt.point(grab.x / Math.max(1, body.width), grab.y / Math.max(1, body.height))
        }
        onPositionChanged: event => {
            if (!pressed) return
            const p = mapToItem(null, event.x, event.y)
            if (!dragged && Math.hypot(p.x - pressAt.x, p.y - pressAt.y) < 8) return
            root.dragPosition = mapToItem(root.parent, event.x, event.y)
            dragged = true
            root.dragMoved(p.x, p.y)
        }
        onReleased: event => {
            if (!dragged) {
                root.clicked()
                return
            }
            const p = mapToItem(null, event.x, event.y)
            root.dragPosition = mapToItem(root.parent, event.x, event.y)
            root.dropped(p.x, p.y)
            if (!root.parked) dragged = false
        }
        onCanceled: root.resetDrag()
    }
}
