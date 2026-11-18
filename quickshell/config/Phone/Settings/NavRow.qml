import QtQuick
import "../../Theme" as Theme
import "../../Components" as Components

MouseArea {
    id: row

    property real pt: 1
    property string icon
    property color tile: Look.accent
    property string label
    property string subtitle
    property string detail
    property bool separated: false
    readonly property real textLeft: 62 * pt

    width: parent.width
    height: (subtitle ? 60 : 44) * pt
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        color: row.pressed ? Look.pressedFill : "transparent"
    }

    Rectangle {
        visible: row.separated
        anchors { top: parent.top; left: parent.left; leftMargin: row.textLeft; right: parent.right }
        height: 1
        color: Look.separator
    }

    Rectangle {
        anchors { left: parent.left; leftMargin: 16 * row.pt; verticalCenter: parent.verticalCenter }
        width: 30 * row.pt
        height: width
        radius: 7 * row.pt
        color: row.tile
        Components.Icon {
            anchors.centerIn: parent
            width: 19 * row.pt
            height: width
            action: row.icon
            iconColor: "white"
        }
    }

    Column {
        anchors { left: parent.left; leftMargin: row.textLeft; right: trailing.left; rightMargin: 8 * row.pt; verticalCenter: parent.verticalCenter }
        spacing: 2 * row.pt
        Text {
            width: parent.width
            text: row.label
            elide: Text.ElideRight
            color: Look.ink
            font { family: Theme.Fonts.family; pixelSize: 17 * row.pt }
        }
        Text {
            visible: row.subtitle !== ""
            width: parent.width
            text: row.subtitle
            elide: Text.ElideRight
            color: Look.secondaryInk
            font { family: Theme.Fonts.family; pixelSize: 13 * row.pt }
        }
    }

    Row {
        id: trailing
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
