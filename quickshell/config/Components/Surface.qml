import QtQuick
import QtQuick.Effects
import "../Theme" as Theme

// A floating surface in Ding's style: a hairline ring and a soft drop shadow.
Rectangle {
    id: root

    color: Theme.Colors.background
    border.width: 1
    border.color: Theme.Colors.ring

    // Negative z draws beneath the surface itself.
    RectangularShadow {
        z: -1
        anchors.fill: parent
        visible: root.visible && root.opacity > 0 && root.width > 0
        radius: root.radius
        offset.y: 4
        blur: 12
        spread: -4
        color: Theme.Colors.shadow
    }
}
