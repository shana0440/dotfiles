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
            visible: Services.Capture.previewActive || Services.Capture.selectingRegion || Services.Capture.startingRecordingGeometry.length > 0
                || (Services.Capture.recordingMode === "region" && Services.Capture.recordingGeometry.length > 0)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "screen-capture-region"
            WlrLayershell.layer: Services.Capture.previewActive ? WlrLayer.Top : WlrLayer.Overlay
            // Hyprland routes pointer input only to exclusive layer surfaces while
            // an exclusive toolbar is open. Include the selector in that group.
            WlrLayershell.keyboardFocus: Services.Capture.previewActive || Services.Capture.selectingRegion
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            // The editor is hidden in full-screen mode; never derive the input
            // region from its visibility when switching into region selection.
            mask: Region { item: Services.Capture.previewActive || Services.Capture.selectingRegion ? overlay.contentItem : null }

            Image {
                anchors.fill: parent
                visible: Services.Capture.previewActive
                readonly property var frame: Services.Capture.preview?.screens.find(screen => screen.name === overlay.modelData.name)
                source: frame ? "file://" + frame.image : ""
                sourceClipRect: frame?.clip
                    ? Qt.rect(frame.clip.x, frame.clip.y, frame.clip.width, frame.clip.height)
                    : Qt.rect(0, 0, 0, 0)
                fillMode: Image.Stretch
                cache: false
            }

            Rectangle {
                anchors.fill: parent
                visible: Services.Capture.previewActive && !Services.Capture.selectingRegion
                color: "#88000000"
            }

            CaptureComponents.RegionEditor {
                id: editor
                anchors.fill: parent
                visible: Services.Capture.selectingRegion || !Services.Capture.previewActive
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

            onVisibleChanged: {
                if (visible && Services.Capture.selectingRegion)
                    Qt.callLater(() => editor.forceActiveFocus())
            }
        }
    }
}
