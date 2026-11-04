import QtQuick
import Quickshell
import Quickshell.Wayland
import "Capture" as CaptureComponents
import "Capture/RegionGeometry.js" as Geometry
import "Services" as Services

Scope {
    id: root
    signal confirmed()
    signal cancelled()

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            screen: modelData
            visible: Services.Capture.capturing || Services.Capture.previewActive || Services.Capture.selectingRegion || Services.Capture.startingRecordingGeometry.length > 0
                || (Services.Capture.recordingMode === "region" && Services.Capture.recordingGeometry.length > 0)
                || (Services.Capture.recordingMode === "window" && Services.Capture.windowGeometry.length > 0)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "screen-capture-region"
            // The window outline appears after the Stop control; keep it one layer lower so
            // its dimming never covers Stop (or the bar's recording indicator).
            WlrLayershell.layer: Services.Capture.capturing || Services.Capture.previewActive
                || Services.Capture.recordingMode === "window" || Services.Capture.startingWindow
                ? WlrLayer.Top : WlrLayer.Overlay
            // Hyprland routes pointer input only to exclusive layer surfaces while
            // an exclusive toolbar is open. Include the selector in that group.
            // Among exclusive surfaces Hyprland prefers the one that became
            // exclusive last, not the higher layer: become exclusive while the
            // frame is still capturing, so the toolbar (mapped once it is ready)
            // always comes later and wins pointer input over this full-screen one.
            WlrLayershell.keyboardFocus: Services.Capture.capturing || Services.Capture.previewActive
                || Services.Capture.selectingRegion
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            // The editor is hidden in full-screen mode; never derive the input
            // region from its visibility when switching into region selection.
            mask: Region { item: Services.Capture.previewActive || Services.Capture.selectingRegion ? overlay.contentItem : null }

            // A fresh view per capture: its first frame is the frozen desktop.
            Loader {
                id: frameLoader
                anchors.fill: parent
                active: Services.Capture.capturing || Services.Capture.previewActive
                sourceComponent: ScreencopyView {
                    captureSource: overlay.modelData
                    live: false
                    paintCursor: false
                    onHasContentChanged: if (hasContent) Services.Capture.frameReady(overlay.modelData.name)
                    onStopped: if (!hasContent) Services.Capture.frameFailed("")
                }
            }

            Connections {
                target: Services.Capture
                function onGrabRequested(directory) {
                    const view = frameLoader.item
                    if (!view || !view.hasContent) {
                        Services.Capture.frameFailed("Could not save the screenshot.")
                        return
                    }
                    // grabToImage scales the requested size by the window's pixel
                    // ratio; ask for it divided so the file is exactly native size.
                    const size = view.sourceSize
                    const request = Qt.size(size.width / overlay.devicePixelRatio, size.height / overlay.devicePixelRatio)
                    const path = directory + "/screen-" + Quickshell.screens.indexOf(overlay.modelData) + ".ppm"
                    const started = view.grabToImage(result => {
                        if (result.saveToFile(path))
                            Services.Capture.frameGrabbed(overlay.modelData.name, path, size.width, size.height)
                        else
                            Services.Capture.frameFailed("Could not save the screenshot.")
                    }, request)
                    if (!started)
                        Services.Capture.frameFailed("Could not save the screenshot.")
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: Services.Capture.previewActive && !Services.Capture.selectingRegion
                    && !Services.Capture.selectingWindow
                color: "#88000000"
            }

            CaptureComponents.RegionEditor {
                id: editor
                anchors.fill: parent
                // Hidden while capturing: its own dim would be photographed into the frozen frame.
                visible: Services.Capture.selectingRegion || (!Services.Capture.previewActive && !Services.Capture.capturing)
                editing: Services.Capture.selectingRegion
                kind: Services.Capture.selectionKind
                activeRegion: editing ? Services.Capture.selectionScreenName === overlay.modelData.name
                    : region.width > 0 && region.height > 0
                region: {
                    if (editing)
                        return Services.Capture.selectionScreenName === overlay.modelData.name
                            ? Services.Capture.selectionRect : ({ x: 0, y: 0, width: 0, height: 0 })
                    const recorded = Geometry.parse(Services.Capture.visibleRecordingGeometry)
                    return recorded ? Geometry.intersection({
                        x: recorded.x - overlay.modelData.x, y: recorded.y - overlay.modelData.y,
                        width: recorded.width, height: recorded.height
                    }, width, height) : ({ x: 0, y: 0, width: 0, height: 0 })
                }
                onSelectionEdited: rectangle => Services.Capture.setRegionSelection(overlay.modelData.name, rectangle)
                onConfirmed: root.confirmed()
                onCancelled: root.cancelled()
            }

            CaptureComponents.WindowSelector {
                anchors.fill: parent
                screenInfo: overlay.modelData
                visible: Services.Capture.selectingWindow
            }

            onVisibleChanged: {
                if (visible && Services.Capture.selectingRegion)
                    Qt.callLater(() => editor.forceActiveFocus())
            }
        }
    }
}
