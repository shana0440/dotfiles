import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    signal poked()
    property bool shown: true
    property bool watching: false

    readonly property real drawingScale: 0.32
    readonly property real peekHeight: 72
    readonly property real headroom: 14
    readonly property bool hovered: touch.containsMouse

    screen: Quickshell.screens[0] ?? null
    visible: shown
    anchors { bottom: true; right: true }
    margins.right: 40
    implicitWidth: Math.ceil(cat.width)
    implicitHeight: peekHeight + headroom
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: cat }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-pet"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    IpcHandler {
        target: "pet"
        function poke(): void { root.poked() }
        function show(): void { root.shown = true }
        function hide(): void { root.shown = false }
        function state(): string {
            return JSON.stringify({ shown: root.shown, watching: root.watching })
        }
    }

    Item {
        id: cat
        width: 380 * root.drawingScale
        height: 235 * root.drawingScale
        y: root.height - root.peekHeight + (root.hovered ? -8 : 0) + (touch.pressed ? 6 : 0)
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

        Item {
            id: drawing
            width: 380
            height: 235
            scale: root.drawingScale
            transformOrigin: Item.TopLeft

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "#4a4a4a"
                    strokeWidth: 20
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathSvg { id: tail; path: "M 80 222 Q 45 200 20 210" }
                }
                ShapePath {
                    strokeWidth: -1
                    fillColor: "#4a4a4a"
                    PathSvg { path: "M 52 180 A 160 112 0 1 1 372 180 A 160 112 0 1 1 52 180 Z" }
                }
                ShapePath {
                    strokeWidth: -1
                    fillColor: "#4a4a4a"
                    PathSvg { path: "M 100 104 L 120 34 Q 128 10 148 24 L 204 74 Z" }
                }
                ShapePath {
                    strokeWidth: -1
                    fillColor: "#4a4a4a"
                    PathSvg { path: "M 226 72 L 278 28 Q 298 12 304 36 L 322 108 Z" }
                }
            }

            Row {
                id: eyes
                x: 194 + (root.watching ? -18 : 0)
                y: 128
                spacing: 50
                Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                Repeater {
                    model: 2
                    Rectangle {
                        width: 24
                        height: 46
                        radius: 12
                        color: "#ffffff"
                        transform: Scale { origin.y: 23; yScale: blink.lid }
                    }
                }
            }
        }

        MouseArea {
            id: touch
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.poked()
        }
    }

    QtObject {
        id: blink
        property real lid: 1
    }

    SequentialAnimation {
        running: root.visible
        loops: Animation.Infinite
        PauseAnimation { duration: 2600 + Math.random() * 2400 }
        NumberAnimation { target: blink; property: "lid"; to: 0.1; duration: 70 }
        NumberAnimation { target: blink; property: "lid"; to: 1; duration: 110 }
    }

    SequentialAnimation {
        running: root.visible && root.hovered
        loops: Animation.Infinite
        alwaysRunToEnd: true
        PropertyAction { target: tail; property: "path"; value: "M 80 222 Q 45 186 26 176" }
        PauseAnimation { duration: 220 }
        PropertyAction { target: tail; property: "path"; value: "M 80 222 Q 45 200 20 210" }
        PauseAnimation { duration: 220 }
    }
}
