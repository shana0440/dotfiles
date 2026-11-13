import QtQuick
import QtQuick.Shapes
import "../Services" as Services
import "../Theme" as Theme

Item {
    id: root
    required property var screenInfo
    readonly property var selected: Services.Capture.selectedWindow
    readonly property real windowX: selected ? selected.x - screenInfo.x : 0
    readonly property real windowY: selected ? selected.y - screenInfo.y : 0
    readonly property bool intersects: selected !== null && windowX < width && windowY < height
        && windowX + selected.width > 0 && windowY + selected.height > 0
    // The highlighted window is cut out of the dimmed screen, like a selected range.
    readonly property real clearX: Math.max(0, windowX)
    readonly property real clearY: Math.max(0, windowY)
    readonly property real clearRight: selected ? Math.min(width, windowX + selected.width) : 0
    readonly property real clearBottom: selected ? Math.min(height, windowY + selected.height) : 0
    clip: true

    function windowAt(x, y) {
        const globalX = screenInfo.x + x
        const globalY = screenInfo.y + y
        return (Services.Capture.preview?.windows ?? []).find(window =>
            globalX >= window.x && globalX < window.x + window.width
            && globalY >= window.y && globalY < window.y + window.height) ?? null
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: mouse => {
            if (!Services.Capture.windowSelectionLocked)
                Services.Capture.selectedWindow = root.windowAt(mouse.x, mouse.y)
        }
        onClicked: mouse => {
            Services.Capture.selectedWindow = root.windowAt(mouse.x, mouse.y)
            Services.Capture.windowSelectionLocked = Services.Capture.selectedWindow !== null
        }
    }

    // Dim everything except the highlighted window (this screen has none: dim all).
    Repeater {
        model: root.intersects ? [
            { x: 0, y: 0, width: root.width, height: root.clearY },
            { x: 0, y: root.clearY, width: root.clearX, height: root.clearBottom - root.clearY },
            { x: root.clearRight, y: root.clearY, width: root.width - root.clearRight, height: root.clearBottom - root.clearY },
            { x: 0, y: root.clearBottom, width: root.width, height: root.height - root.clearBottom }
        ] : [{ x: 0, y: 0, width: root.width, height: root.height }]

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
        visible: root.intersects
        x: root.clearX - 1
        y: root.clearY - 1
        width: root.clearRight - root.clearX + 2
        height: root.clearBottom - root.clearY + 2

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

    Rectangle {
        visible: root.intersects || root.selected === null
        width: Math.min(label.implicitWidth + 24, root.width - 24)
        height: label.implicitHeight + 16
        x: Math.max(12, Math.min(root.width - width - 12, root.clearX))
        y: Math.max(12, Math.min(root.height - height - 120, root.clearY - height - 12))
        radius: 7
        color: Theme.Colors.panel
        Text {
            id: label
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.width - 48)
            text: root.selected
                ? root.selected.title + "\n" + (Services.Capture.windowSelectionLocked ? "Selected · " : "Click to select · ")
                    + (Services.Capture.windowSelectionKind === "recording" ? "Enter to record" : "Enter to capture")
                : (Services.Capture.preview === null ? "Loading windows…"
                    : Services.Capture.preview.windowError || "Point at a window and click to select it")
            textFormat: Text.PlainText
            color: Theme.Colors.foreground
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
