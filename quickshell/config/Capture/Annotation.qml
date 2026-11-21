import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property var operation: null
    readonly property string kind: operation?.kind ?? ""
    readonly property color strokeColor: operation?.color ?? "transparent"
    readonly property real strokeWidth: operation?.width ?? 0

    Shape {
        visible: root.kind === "pen"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: root.kind === "pen" ? root.operation.points : [] }
        }
    }
}
