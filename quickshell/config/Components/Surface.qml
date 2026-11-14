import QtQuick
import QtQuick.Effects
import "../Theme" as Theme

// A floating surface in Ding's style: a hairline edge and a soft drop shadow. The
// transparent theme clears the fill and edge, and with the fill the shadow.
Rectangle {
    id: root

    // Another item paints this surface (see IslandGoo); keep only the content.
    property bool bare: false

    color: bare ? Theme.Colors.transparent : Theme.Colors.surfaceFill
    border.width: bare ? 0 : 1
    border.color: Theme.Colors.surfaceEdge

    // Negative z draws beneath the surface itself.
    RectangularShadow {
        z: -1
        anchors.fill: parent
        visible: !root.bare && root.color.a > 0 && root.visible && root.opacity > 0 && root.width > 0
        radius: root.radius
        offset.y: 4
        blur: 12
        spread: -4
        // Fades with the fill, so a surface clearing for the transparent theme
        // takes its shadow with it.
        color: Qt.alpha(Theme.Colors.shadow, Theme.Colors.shadow.a * root.color.a)
    }
}
