import QtQuick
import QtQuick.Shapes
import "../Theme" as Theme

Item {
    id: root

    property color color: Theme.Colors.accent
    implicitWidth: 20
    implicitHeight: 20
    Accessible.role: Accessible.ProgressBar
    Accessible.name: "Taking screenshot"

    Shape {
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - 2
                radiusY: root.height / 2 - 2
                startAngle: -90
                sweepAngle: 270
            }
        }

        RotationAnimator on rotation {
            objectName: "spinnerAnimation"
            from: 0
            to: 360
            duration: 800
            loops: Animation.Infinite
            running: root.visible
        }
    }
}
