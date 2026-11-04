import QtQuick
import Quickshell
import Quickshell.Wayland
import "Capture" as CaptureComponents
import "Capture/RegionGeometry.js" as Geometry
import "Services" as Services

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            screen: modelData
            visible: Services.Capture.selectingRegion || Services.Capture.startingRecordingGeometry.length > 0
                || (Services.Capture.recordingMode === "region" && Services.Capture.recordingGeometry.length > 0)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "screen-capture-region"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: Services.Capture.selectingRegion
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            mask: Region { item: Services.Capture.selectingRegion ? editor : null }

            CaptureComponents.RegionEditor {
                id: editor
                anchors.fill: parent
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
                onConfirmed: Services.Capture.confirmRegionSelection()
                onCancelled: Services.Capture.cancelRegionSelection()
            }

            onVisibleChanged: {
                if (visible && Services.Capture.selectingRegion)
                    Qt.callLater(() => editor.forceActiveFocus())
            }
        }
    }
}
