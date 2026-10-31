import QtQuick
import Quickshell
import Quickshell.Wayland
import "Bar" as BarComponents
import "Theme" as Theme

PanelWindow {
    id: root

    readonly property bool menuOpen: centerIsland.expanded || rightIsland.expanded

    function closeMenus() {
        centerIsland.expanded = false
        rightIsland.close()
    }

    onMenuOpenChanged: {
        if (menuOpen) {
            Qt.callLater(() => {
                if (root.menuOpen)
                    barContent.forceActiveFocus()
            })
        }
    }

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

    // Keep room for expanded menus without resizing the underlying surface.
    implicitHeight: 600
    exclusiveZone: 32
    color: Theme.Colors.transparent
    WlrLayershell.keyboardFocus: menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    mask: Region {
        item: leftIsland
        Region { item: centerIsland }
        Region { item: rightIsland }
    }

    // The bar stays above these transparent outside-click catchers.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.menuOpen
            color: Theme.Colors.transparent
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.closeMenus()
            }
        }
    }

    FocusScope {
        id: barContent
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeMenus()

        TapHandler {
            enabled: root.menuOpen
            acceptedButtons: Qt.AllButtons
            gesturePolicy: TapHandler.DragThreshold
            onTapped: eventPoint => {
                const centerPosition = centerIsland.mapFromItem(barContent, eventPoint.position.x, eventPoint.position.y)
                const rightPosition = rightIsland.mapFromItem(barContent, eventPoint.position.x, eventPoint.position.y)
                if (centerIsland.expanded && !centerIsland.contains(centerPosition))
                    centerIsland.expanded = false
                if (rightIsland.expanded && !rightIsland.contains(rightPosition))
                    rightIsland.close()
            }
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
}
