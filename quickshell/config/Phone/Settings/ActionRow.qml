import QtQuick
import "../../Theme" as Theme
import "../../Components" as Components

MouseArea {
    id: row

    property real pt: 1
    property string icon
    property string label
    property color tint: Look.accent
    property bool separated: false

    width: parent.width
    height: 50 * pt
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        color: row.pressed ? Look.pressedFill : "transparent"
    }

    Rectangle {
        visible: row.separated
        anchors { top: parent.top; left: parent.left; leftMargin: 62 * row.pt; right: parent.right; rightMargin: 16 * row.pt }
        height: 1
        color: Look.separator
    }

    Components.Icon {
        anchors { left: parent.left; leftMargin: 19 * row.pt; verticalCenter: parent.verticalCenter }
        width: 24 * row.pt
        height: width
        action: row.icon
        iconColor: row.tint
    }

    Text {
        anchors { left: parent.left; leftMargin: 62 * row.pt; verticalCenter: parent.verticalCenter }
        text: row.label
        color: row.tint
        font { family: Theme.Fonts.family; pixelSize: 17 * row.pt }
    }
}
