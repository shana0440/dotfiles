import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes

ToolButton {
    id: root
    property bool region: false
    property bool windowMode: false
    property bool recording: false

    implicitWidth: 48
    implicitHeight: 46
    hoverEnabled: true
    Accessible.name: text
    ToolTip.visible: hovered
    ToolTip.text: text
    ToolTip.delay: 500

    background: Rectangle {
        radius: 7
        color: root.checked ? "#707078" : root.hovered ? "#52525a" : "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: "#c4b5fd"
    }
    contentItem: Item {
        Shape {
            anchors.centerIn: parent
            width: 28
            height: 24
            opacity: root.enabled ? 1 : 0.35
            ShapePath {
                strokeColor: "#f0f0f2"
                strokeWidth: 2
                strokeStyle: root.region ? ShapePath.DashLine : ShapePath.SolidLine
                dashPattern: [2, 2]
                fillColor: "transparent"
                startX: 1; startY: 2
                PathLine { x: 27; y: 2 }
                PathLine { x: 27; y: 22 }
                PathLine { x: 1; y: 22 }
                PathLine { x: 1; y: 2 }
            }
            Rectangle {
                visible: !root.region && !root.windowMode
                x: 5; y: 17; width: 18; height: 2
                color: "#f0f0f2"
            }
            Rectangle {
                visible: root.windowMode
                x: 2; y: 7; width: 24; height: 2
                color: "#f0f0f2"
            }
            Rectangle {
                visible: root.recording
                x: 19; y: 16; width: 13; height: 13
                radius: 7
                color: "#e2e2e6"
                border.width: 2
                border.color: root.checked ? "#707078" : "#38383f"
            }
        }
    }
}
