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
        bottom: true
        left: true
        right: true
    }

    // Keep a fixed full-screen surface, with visual margins applied to the content.
    // This lets an open menu catch clicks even at the screen edges and over fullscreen apps.
    exclusionMode: ExclusionMode.Ignore
    color: Theme.Colors.transparent
    WlrLayershell.keyboardFocus: menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Let fullscreen windows cover the normal bar; open menus use a full-screen overlay.
    WlrLayershell.layer: menuOpen ? WlrLayer.Overlay : WlrLayer.Top

    // A separate input-transparent strip reserves the same 20px margin + 32px bar.
    // A surface anchored to all four edges cannot reserve only the top edge.
    PanelWindow {
        screen: root.screen
        visible: root.visible
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 52
        exclusiveZone: 52
        color: Theme.Colors.transparent
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-reservation"
        mask: Region {}
    }

    mask: Region {
        item: root.menuOpen ? root.contentItem : leftIsland
        Region { item: centerIsland }
        Region { item: rightIsland }
    }

    // The main surface covers its own monitor; cover the other monitors above fullscreen too.
    Variants {
        model: Quickshell.screens.filter(screen => screen !== root.screen)

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.menuOpen
            color: Theme.Colors.transparent
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
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

    // Behind the islands, but above apps whenever a menu is open.
    MouseArea {
        anchors.fill: parent
        enabled: root.menuOpen
        acceptedButtons: Qt.AllButtons
        onPressed: root.closeMenus()
    }

    FocusScope {
        id: barContent
        anchors.fill: parent
        anchors.topMargin: 20
        anchors.leftMargin: 20
        anchors.rightMargin: 20
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
