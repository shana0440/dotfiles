import QtQuick
import QtQuick.Effects
import "../Theme" as Theme

Rectangle {
    id: root

    property bool bare: false
    property real clearness: Theme.Colors.clearness

    color: bare ? Theme.Colors.transparent : Theme.Colors.surfaceFill(clearness)
    border.width: bare ? 0 : 1
    border.color: Theme.Colors.surfaceEdge(clearness)

    RectangularShadow {
        z: -1
        anchors.fill: parent
        visible: !root.bare && root.color.a > 0 && root.visible && root.opacity > 0 && root.width > 0
        radius: root.radius
        offset.y: 4
        blur: 12
        spread: -4
        color: Qt.alpha(Theme.Colors.shadow, Theme.Colors.shadow.a * root.color.a)
    }
}
