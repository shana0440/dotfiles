import QtQuick
import QtQuick.Shapes
import "../Theme" as Theme

Item {
    id: root

    property var operation: null
    readonly property string kind: operation?.kind ?? ""
    readonly property color strokeColor: operation?.color ?? "transparent"
    readonly property real stroke: operation?.stroke ?? 0
    readonly property rect box: operation?.from && operation?.to
        ? Qt.rect(Math.min(operation.from.x, operation.to.x), Math.min(operation.from.y, operation.to.y),
            Math.abs(operation.to.x - operation.from.x), Math.abs(operation.to.y - operation.from.y))
        : Qt.rect(0, 0, 0, 0)

    component Stroke: ShapePath {
        strokeColor: root.strokeColor
        strokeWidth: root.stroke
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
    }

    Shape {
        visible: root.kind === "pen"
        preferredRendererType: Shape.CurveRenderer
        Stroke {
            PathPolyline { path: root.kind === "pen" ? root.operation.points : [] }
        }
    }

    Text {
        visible: root.kind === "text"
        x: root.operation?.at?.x ?? 0
        y: root.operation?.at?.y ?? 0
        text: root.operation?.text ?? ""
        textFormat: Text.PlainText
        color: root.strokeColor
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        font.pixelSize: root.operation?.size ?? 12
    }

    Shape {
        visible: root.kind === "rect"
        preferredRendererType: Shape.CurveRenderer
        Stroke {
            PathRectangle {
                x: root.box.x
                y: root.box.y
                width: root.box.width
                height: root.box.height
            }
        }
    }

    Shape {
        visible: root.kind === "ellipse"
        preferredRendererType: Shape.CurveRenderer
        Stroke {
            PathAngleArc {
                moveToStart: true
                centerX: root.box.x + root.box.width / 2
                centerY: root.box.y + root.box.height / 2
                radiusX: root.box.width / 2
                radiusY: root.box.height / 2
                startAngle: 0
                sweepAngle: 360
            }
        }
    }
}
