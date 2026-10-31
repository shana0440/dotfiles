import QtQuick
import Quickshell
import Quickshell.Wayland
import "Bar" as BarComponents
import "Theme" as Theme

PanelWindow {
    id: root

    readonly property int islandMargin: 20
    readonly property int compactIslandHeight: 32
    readonly property int reservedTopHeight: islandMargin + compactIslandHeight
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

    // A fixed native surface keeps window resizing from interrupting island animations.
    exclusionMode: ExclusionMode.Ignore
    color: Theme.Colors.transparent
    WlrLayershell.keyboardFocus: menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.layer: menuOpen ? WlrLayer.Overlay : WlrLayer.Top

    // Layer-shell infers the reservation edge from three-edge anchoring.
    PanelWindow {
        id: topReservation
        screen: root.screen
        visible: root.visible
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: root.reservedTopHeight
        exclusiveZone: root.reservedTopHeight
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

    Variants {
        id: otherMonitorDismissalSurfaces
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

    MouseArea {
        id: outsideClickArea
        anchors.fill: parent
        enabled: root.menuOpen
        acceptedButtons: Qt.AllButtons
        onPressed: root.closeMenus()
    }

    FocusScope {
        id: barContent
        anchors.fill: parent
        anchors.topMargin: root.islandMargin
        anchors.leftMargin: root.islandMargin
        anchors.rightMargin: root.islandMargin
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
            height: root.compactIslandHeight
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
