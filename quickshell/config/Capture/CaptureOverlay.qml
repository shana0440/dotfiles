import QtQuick
import Quickshell
import Quickshell.Wayland
import "RegionGeometry.js" as Geometry
import "../Theme" as Theme
import "../Services" as Services

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
            color: Theme.Colors.transparent
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell-capture-region"
            WlrLayershell.layer: interactive ? WlrLayer.Overlay : WlrLayer.Top
            readonly property bool interactive: Services.Capture.capturing
                || Services.Capture.previewActive || Services.Capture.selectingRegion
            WlrLayershell.keyboardFocus: interactive && !Services.Capture.toolbarVisible
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            mask: Region { item: overlay.interactive ? overlay.contentItem : null }

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
                color: Theme.Colors.scrim
            }

            RegionEditor {
                id: editor
                anchors.fill: parent
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

            WindowSelector {
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
