import QtQuick
import QtQuick.Effects
import "../Theme" as Theme

// A floating surface in Ding's style: a hairline ring and a soft drop shadow.
Rectangle {
    id: root

    // Another item paints this surface (see IslandGoo); keep only the content.
    property bool bare: false

    color: bare ? Theme.Colors.transparent : Theme.Colors.background
    border.width: bare ? 0 : 1
    border.color: Theme.Colors.ring

    // Negative z draws beneath the surface itself.
    RectangularShadow {
        z: -1
        anchors.fill: parent
        visible: !root.bare && root.visible && root.opacity > 0 && root.width > 0
        radius: root.radius
        offset.y: 4
        blur: 12
        spread: -4
        color: Theme.Colors.shadow
    }
}
