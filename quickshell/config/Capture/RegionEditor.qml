import QtQuick
import QtQuick.Shapes
import "RegionGeometry.js" as Geometry
import "../Theme" as Theme

Item {
    id: root

    property bool editing: false
    property bool activeRegion: false
    property bool dragging: false
    property string kind: "screenshot"
    property var region: ({ x: 0, y: 0, width: 0, height: 0 })
    readonly property bool hasRegion: activeRegion && region.width > 0 && region.height > 0
    readonly property bool adjustable: editing
    // Leave fractional-scale edge pixels clear of the recording's shade and border.
    readonly property int capturePadding: editing ? 0 : 1
    readonly property var clearRegion: Geometry.intersection({
        x: region.x - capturePadding, y: region.y - capturePadding,
        width: region.width + 2 * capturePadding, height: region.height + 2 * capturePadding
    }, width, height)

    signal selectionEdited(var rectangle)
    signal confirmed()
    signal cancelled()

    focus: editing
    Keys.onEscapePressed: if (editing) root.cancelled()
    Keys.onReturnPressed: if (editing && hasRegion && !dragging) root.confirmed()
    Keys.onEnterPressed: if (editing && hasRegion && !dragging) root.confirmed()

    MouseArea {
        anchors.fill: parent
        enabled: root.editing
        cursorShape: Qt.CrossCursor
        property point start
        onPressed: mouse => {
            root.dragging = true
            start = Qt.point(mouse.x, mouse.y)
            root.selectionEdited(Geometry.fromPoints(start, start, root.width, root.height))
        }
        onPositionChanged: mouse => {
            if (pressed)
                root.selectionEdited(Geometry.fromPoints(start, Qt.point(mouse.x, mouse.y), root.width, root.height))
        }
        onReleased: root.dragging = false
        onCanceled: root.dragging = false
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.hasRegion
        color: Theme.Colors.scrim
    }

    Repeater {
        model: root.hasRegion ? [
            { x: 0, y: 0, width: root.width, height: root.clearRegion.y },
            { x: 0, y: root.clearRegion.y, width: root.clearRegion.x, height: root.clearRegion.height },
            { x: root.clearRegion.x + root.clearRegion.width, y: root.clearRegion.y,
                width: root.width - root.clearRegion.x - root.clearRegion.width, height: root.clearRegion.height },
            { x: 0, y: root.clearRegion.y + root.clearRegion.height,
                width: root.width, height: root.height - root.clearRegion.y - root.clearRegion.height }
        ] : []

        Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: modelData.width
            height: modelData.height
            color: Theme.Colors.scrim
        }
    }

    Shape {
        id: outline
        visible: root.hasRegion
        x: root.clearRegion.x - 1
        y: root.clearRegion.y - 1
        width: root.clearRegion.width + 2
        height: root.clearRegion.height + 2

        ShapePath {
            strokeColor: Theme.Colors.foreground
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            capStyle: ShapePath.FlatCap
            fillColor: Theme.Colors.transparent
            startX: 0.5
            startY: 0.5
            PathLine { x: outline.width - 0.5; y: 0.5 }
            PathLine { x: outline.width - 0.5; y: outline.height - 0.5 }
            PathLine { x: 0.5; y: outline.height - 0.5 }
            PathLine { x: 0.5; y: 0.5 }
        }
    }

    MouseArea {
        x: root.region.x
        y: root.region.y
        width: root.region.width
        height: root.region.height
        enabled: root.adjustable && root.activeRegion
        cursorShape: Qt.SizeAllCursor
        property var initialRegion
        property point start
        onPressed: mouse => {
            root.dragging = true
            initialRegion = root.region
            start = mapToItem(root, mouse.x, mouse.y)
        }
        onPositionChanged: mouse => {
            if (pressed) {
                const point = mapToItem(root, mouse.x, mouse.y)
                root.selectionEdited(Geometry.move(initialRegion, point.x - start.x, point.y - start.y, root.width, root.height))
            }
        }
        onReleased: root.dragging = false
        onCanceled: root.dragging = false
    }

    Repeater {
        model: root.editing && root.hasRegion ? [
            { edge: "nw", h: -1, v: -1, cursor: Qt.SizeFDiagCursor },
            { edge: "n", h: 0, v: -1, cursor: Qt.SizeVerCursor },
            { edge: "ne", h: 1, v: -1, cursor: Qt.SizeBDiagCursor },
            { edge: "e", h: 1, v: 0, cursor: Qt.SizeHorCursor },
            { edge: "se", h: 1, v: 1, cursor: Qt.SizeFDiagCursor },
            { edge: "s", h: 0, v: 1, cursor: Qt.SizeVerCursor },
            { edge: "sw", h: -1, v: 1, cursor: Qt.SizeBDiagCursor },
            { edge: "w", h: -1, v: 0, cursor: Qt.SizeHorCursor }
        ] : []

        Rectangle {
            required property var modelData
            objectName: "selectionHandle-" + modelData.edge
            x: root.region.x + root.region.width * (modelData.h + 1) / 2 - width / 2
            y: root.region.y + root.region.height * (modelData.v + 1) / 2 - height / 2
            width: 8
            height: 8
            radius: width / 2
            antialiasing: true
            color: Theme.Colors.foreground
            border.color: Theme.Colors.track

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: modelData.cursor
                enabled: root.adjustable
                property var initialRegion
                property point start
                onPressed: mouse => {
                    root.dragging = true
                    initialRegion = root.region
                    start = mapToItem(root, mouse.x, mouse.y)
                }
                onPositionChanged: mouse => {
                    if (pressed) {
                        const point = mapToItem(root, mouse.x, mouse.y)
                        root.selectionEdited(Geometry.resize(initialRegion, modelData.edge,
                            point.x - start.x, point.y - start.y, root.width, root.height))
                    }
                }
                onReleased: root.dragging = false
                onCanceled: root.dragging = false
            }
        }
    }

    RegionSizeLabel {
        objectName: "regionSizeLabel"
        visible: root.editing && root.hasRegion
        regionWidth: Math.round(root.region.width)
        regionHeight: Math.round(root.region.height)
        recording: root.kind === "recording"
        x: Math.max(12, Math.min(root.width - width - 12, root.region.x + (root.region.width - width) / 2))
        // Keep the size hint clear of the bottom capture toolbar.
        y: Math.max(12, root.region.y + root.region.height + height + 16 < root.height - 120
            ? root.region.y + root.region.height + 16 : root.region.y - height - 16)
    }
}
