import QtQuick
import "../Services" as Services

Item {
    id: root
    required property var screenInfo
    readonly property var selected: Services.Capture.selectedWindow
    readonly property real windowX: selected ? selected.x - screenInfo.x : 0
    readonly property real windowY: selected ? selected.y - screenInfo.y : 0
    readonly property bool intersects: selected !== null && windowX < width && windowY < height
        && windowX + selected.width > 0 && windowY + selected.height > 0
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

    Rectangle {
        visible: root.intersects
        x: root.windowX
        y: root.windowY
        width: root.selected?.width ?? 0
        height: root.selected?.height ?? 0
        radius: 4
        color: "#3393c5fd"
        border.width: 3
        border.color: Services.Capture.windowSelectionLocked ? "#a78bfa" : "#93c5fd"
    }

    Rectangle {
        visible: root.intersects || root.selected === null
        width: Math.min(label.implicitWidth + 24, root.width - 24)
        height: label.implicitHeight + 16
        x: Math.max(12, Math.min(root.width - width - 12, root.windowX))
        y: Math.max(12, Math.min(root.height - height - 120, root.windowY - height - 12))
        radius: 7
        color: "#ed121212"
        Text {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.width - 48)
            text: root.selected
                ? root.selected.title + "\n" + (Services.Capture.windowSelectionLocked ? "Selected · " : "Click to select · ")
                    + (Services.Capture.windowSelectionKind === "recording" ? "Enter to record" : "Enter to capture")
                : (Services.Capture.preview === null ? "Loading windows…"
                    : Services.Capture.preview.windowError || "Point at a window and click to select it")
            textFormat: Text.PlainText
            color: "white"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
