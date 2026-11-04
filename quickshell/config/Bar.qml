import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Bar" as BarComponents
import "Theme" as Theme
import "Services" as Services

PanelWindow {
    id: root

    readonly property int islandMargin: 20
    readonly property int compactIslandHeight: 32
    readonly property int islandSpacing: 8
    readonly property int reservedTopHeight: islandMargin + compactIslandHeight
    readonly property bool menuOpen: centerIsland.expanded || rightIsland.expanded
    readonly property bool menuNeedsKeyboardFocus: centerIsland.expanded || rightIsland.keyboardFocusRequired

    function closeMenus() {
        centerIsland.close()
        rightIsland.close()
    }

    IpcHandler {
        target: "inputMenu"
        function close() {
            if (rightIsland.mode === "input")
                rightIsland.close()
        }
    }

    onMenuOpenChanged: {
        if (menuOpen) {
            Qt.callLater(() => {
                if (root.menuOpen && root.menuNeedsKeyboardFocus)
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
    WlrLayershell.keyboardFocus: menuNeedsKeyboardFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Let overlapping floating windows cover the idle bar, but keep menus and alerts above apps.
    WlrLayershell.layer: menuOpen || centerIsland.notificationVisible || Services.Capture.recording
        ? WlrLayer.Overlay : WlrLayer.Bottom

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
        item: root.menuOpen ? root.contentItem : workspaceIsland
        Region { item: appsIsland.visible ? appsIsland : null }
        Region { item: centerIsland }
        Region { item: mediaIsland.visible ? mediaIsland : null }
        Region { item: notificationIsland.visible ? notificationIsland : null }
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
            function containsBarPoint(item, position) {
                return item.visible && item.contains(item.mapFromItem(barContent, position.x, position.y))
            }

            onTapped: eventPoint => {
                const position = eventPoint.position
                const onCenterGroup = containsBarPoint(centerIsland, position)
                    || containsBarPoint(mediaIsland, position)
                    || containsBarPoint(notificationIsland, position)
                if (centerIsland.expanded && !onCenterGroup)
                    centerIsland.close()
                if (rightIsland.expanded && !containsBarPoint(rightIsland, position))
                    rightIsland.close()
            }
        }

        BarComponents.WorkspaceIsland {
            id: workspaceIsland
            anchors.left: parent.left
            height: root.compactIslandHeight
        }

        BarComponents.AppsIsland {
            id: appsIsland
            anchors.left: workspaceIsland.right
            anchors.leftMargin: root.islandSpacing
            height: root.compactIslandHeight
            availableWidth: Math.max(0, (mediaIsland.visible ? mediaIsland.x : centerIsland.x)
                - x - root.islandSpacing)
        }

        BarComponents.CenterIsland {
            id: centerIsland
            anchors.horizontalCenter: parent.horizontalCenter
            availableHeight: Math.min(560, Math.max(144, root.height - root.islandMargin * 2))
        }

        BarComponents.MediaIsland {
            id: mediaIsland
            anchors.right: centerIsland.left
            anchors.rightMargin: merged ? -width : root.islandSpacing
            merged: centerIsland.sideIslandsMerged
            onClicked: centerIsland.open("media")
        }

        BarComponents.NotificationIsland {
            id: notificationIsland
            anchors.left: centerIsland.right
            anchors.leftMargin: merged ? -width : root.islandSpacing
            merged: centerIsland.sideIslandsMerged
            onClicked: centerIsland.open("notifications")
        }

        BarComponents.RightIsland {
            id: rightIsland
            anchors.right: parent.right
            availableHeight: Math.max(200, root.height - root.islandMargin * 2)
        }
    }
}
