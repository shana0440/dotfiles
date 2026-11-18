import QtQuick
import "../../Theme" as Theme
import "../../Components" as Components

MouseArea {
    id: row

    property real pt: 1
    property string label
    property string detail
    property bool separated: false

    width: parent.width
    height: 44 * pt
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        color: row.pressed ? Look.pressedFill : "transparent"
    }

    Rectangle {
        visible: row.separated
        anchors { top: parent.top; left: parent.left; leftMargin: 16 * row.pt; right: parent.right }
        height: 1
        color: Look.hairline
    }

    Text {
        anchors { left: parent.left; leftMargin: 16 * row.pt; verticalCenter: parent.verticalCenter }
        text: row.label
        color: Look.ink
        font { family: Theme.Fonts.family; pixelSize: 17 * row.pt }
    }

    Row {
        anchors { right: parent.right; rightMargin: 10 * row.pt; verticalCenter: parent.verticalCenter }
        spacing: 4 * row.pt
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: row.detail
            color: Look.secondaryInk
            font { family: Theme.Fonts.family; pixelSize: 17 * row.pt }
        }
        Components.Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 20 * row.pt
            height: width
            action: "forward"
            iconColor: Look.hairline
        }
    }
}
