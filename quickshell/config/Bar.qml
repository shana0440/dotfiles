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
        centerIsland.expanded = false
        rightIsland.close()
    }

    function openCaptureMenu() {
        Services.Capture.cancelRegionSelection()
        captureDelay.stop()
        rightIsland.close()
        centerIsland.open("capture")
    }

    IpcHandler {
        target: "capture"
        function openMenu() { root.openCaptureMenu() }
        function cancelSelection() { Services.Capture.cancelRegionSelection() }
        function takeScreenshot(mode: string) {
            if (root.menuOpen) {
                root.requestCapture("takeScreenshot", mode)
            } else {
                captureDelay.stop()
                Services.Capture.cancelRegionSelection()
                Services.Capture.takeScreenshot(mode, root.screen.name)
            }
        }
        function selectRegion(kind: string) {
            captureDelay.stop()
            root.closeMenus()
            Services.Capture.beginRegionSelection(kind, root.screen.name)
        }
    }

    IpcHandler {
        target: "inputMenu"
        function close() {
            if (rightIsland.mode === "input")
                rightIsland.close()
        }
    }

    function requestCapture(action, mode) {
        captureDelay.stop()
        Services.Capture.cancelRegionSelection()
        if (action === "takeScreenshot" && mode === "full")
            Services.Capture.prepareScreenshot()
        closeMenus()
        if (action === "stopRecording") {
            Services.Capture.stopRecording()
        } else {
            captureDelay.action = action
            captureDelay.mode = mode
            captureDelay.restart()
        }
    }

    // Release menu input grabs and finish the island animation before capture starts.
    Timer {
        id: captureDelay
        property string action: ""
        property string mode: ""
        interval: centerIsland.resizeDuration + centerIsland.fadeDuration
        onTriggered: {
            if (action === "takeScreenshot")
                Services.Capture.takeScreenshot(mode, root.screen.name)
            else if (action === "startRecording")
                Services.Capture.startRecording(mode, root.screen.name)
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
    WlrLayershell.layer: menuOpen || centerIsland.notificationVisible || Services.Capture.recording || Services.Capture.takingScreenshot
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
        Region { item: settingsIsland.visible ? settingsIsland : null }
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
                    || containsBarPoint(mediaIsland, position) || containsBarPoint(settingsIsland, position)
                if (centerIsland.expanded && !onCenterGroup)
                    centerIsland.expanded = false
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
            onCaptureRequested: (action, mode) => root.requestCapture(action, mode)
        }

        BarComponents.SettingsIsland {
            id: settingsIsland
            anchors.left: centerIsland.right
            anchors.leftMargin: merged ? -width : root.islandSpacing
            merged: centerIsland.sideIslandsMerged && !Services.Capture.takingScreenshot
            onClicked: root.openCaptureMenu()
        }

        BarComponents.MediaIsland {
            id: mediaIsland
            anchors.right: centerIsland.left
            anchors.rightMargin: merged ? -width : root.islandSpacing
            merged: centerIsland.sideIslandsMerged
            onClicked: centerIsland.open("media")
        }

        BarComponents.RightIsland {
            id: rightIsland
            anchors.right: parent.right
            availableHeight: Math.max(200, root.height - root.islandMargin * 2)
        }
    }
}
