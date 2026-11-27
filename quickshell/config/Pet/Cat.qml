import QtQuick
import QtQuick.Shapes
import "../Theme" as Theme

Item {
    id: cat

    readonly property real drawingScale: 0.32
    readonly property real sitLine: 72
    property real facing: 1
    property real squash: 1
    property real spin: 0
    property bool wagging: false

    width: 380 * drawingScale
    height: 235 * drawingScale

    Item {
        anchors.fill: parent
        transform: [
            Scale { origin.x: cat.width / 2; xScale: cat.facing },
            Scale { origin.x: cat.width / 2; origin.y: cat.sitLine; yScale: cat.squash; xScale: 2 - cat.squash },
            Rotation { origin.x: cat.width / 2; origin.y: cat.sitLine * 0.75; angle: cat.spin }
        ]

        Item {
            width: 380
            height: 235
            scale: cat.drawingScale
            transformOrigin: Item.TopLeft

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Theme.Colors.background
                    strokeWidth: 20
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathSvg { id: tail; path: "M 80 222 Q 45 200 20 210" }
                }
                ShapePath {
                    strokeWidth: -1
                    fillColor: Theme.Colors.background
                    PathSvg { path: "M 52 180 A 160 112 0 1 1 372 180 A 160 112 0 1 1 52 180 Z" }
                }
                ShapePath {
                    strokeWidth: -1
                    fillColor: Theme.Colors.background
                    PathSvg { path: "M 100 104 L 120 34 Q 128 10 148 24 L 204 74 Z" }
                }
                ShapePath {
                    strokeWidth: -1
                    fillColor: Theme.Colors.background
                    PathSvg { path: "M 226 72 L 278 28 Q 298 12 304 36 L 322 108 Z" }
                }
            }

            Row {
                x: 194
                y: 128
                spacing: 50

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
    }

    QtObject {
        id: blink
        property real lid: 1
    }

    SequentialAnimation {
        running: cat.visible
        loops: Animation.Infinite
        PauseAnimation { duration: 2600 + Math.random() * 2400 }
        NumberAnimation { target: blink; property: "lid"; to: 0.1; duration: 70 }
        NumberAnimation { target: blink; property: "lid"; to: 1; duration: 110 }
    }

    SequentialAnimation {
        running: cat.visible && cat.wagging
        loops: Animation.Infinite
        alwaysRunToEnd: true
        PropertyAction { target: tail; property: "path"; value: "M 80 222 Q 45 186 26 176" }
        PauseAnimation { duration: 220 }
        PropertyAction { target: tail; property: "path"; value: "M 80 222 Q 45 200 20 210" }
        PauseAnimation { duration: 220 }
    }
}
