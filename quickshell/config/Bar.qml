import QtQuick
import Quickshell
import Quickshell.Wayland
import "Bar" as BarComponents
import "Theme" as Theme

PanelWindow {
    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 20
        left: 20
        right: 20
    }

    // Keep the surface fixed so expanding the center never resizes the other islands.
    // The input mask lets clicks pass through the unused transparent area.
    implicitHeight: 300
    exclusiveZone: 32
    color: Theme.Colors.transparent
    // Keep the surface's keyboard mode stable when opening or closing a menu.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Only the islands accept input, including while the center is expanded.
    mask: Region {
        item: leftIsland
        Region { item: centerIsland }
        Region { item: rightIsland }
    }

    BarComponents.LeftIsland {
        id: leftIsland
        anchors.left: parent.left
        height: 32
    }

    BarComponents.CenterIsland {
        id: centerIsland
        anchors.horizontalCenter: parent.horizontalCenter
    }

    BarComponents.RightIsland {
        id: rightIsland
        anchors.right: parent.right
    }
}
