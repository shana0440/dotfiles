import QtQuick
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool backPointed: false
    property string backLabel: "Back to settings"
    property int maximumHeight: 560
    readonly property int bodyMaximumHeight: maximumHeight - body.y - 20
    default property alias content: body.data
    property alias actions: actionRow.data
    signal backRequested()

    implicitWidth: 480
    implicitHeight: body.y + body.implicitHeight + 20

    Item {
        id: header
        x: 20
        y: 20
        width: parent.width - 40
        height: 32

        Components.IconButton {
            id: back
            x: -6
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            iconSize: 18
            icon: "back"
            tooltip: root.backLabel
            selected: root.backPointed
            onClicked: root.backRequested()
        }
        Column {
            anchors.left: back.right
            anchors.leftMargin: 2
            anchors.right: actionRow.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: root.title
                elide: Text.ElideRight
                color: Theme.Colors.foreground
                font.family: Theme.Fonts.family
                font.pixelSize: 16
                font.bold: true
            }
            Text {
                width: parent.width
                text: root.subtitle
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 11
            }
        }
        Row {
            id: actionRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
        }
    }

    Column {
        id: body
        x: 20
        y: header.y + header.height + 12
        width: parent.width - 40
        spacing: 12
    }
}
