import QtQuick
import Quickshell.Widgets
import "../../Theme" as Theme
import "../../Components" as Components
import "../../Services" as Services
import ".." as Phone

Page {
    id: page

    title: "Chat background"
    backLabel: "Settings"

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 20 * page.pt
        bottomPadding: 12 * page.pt

        Choice {
            label: "Default"
            selected: !Services.ChatBackground.usingCustom
            source: Services.ChatBackground.defaultImage
            onClicked: Services.ChatBackground.useDefault()
        }

        Choice {
            label: "Custom"
            selected: Services.ChatBackground.usingCustom
            source: Services.ChatBackground.customImage
            dimmed: true
            onClicked: Services.ChatBackground.useCustom()
        }
    }

    Group {
        pt: page.pt
        ActionRow {
            pt: page.pt
            icon: "background"
            label: Services.ChatBackground.customImage ? "Choose another image" : "Choose image"
            onClicked: Services.ChatBackground.choose()
        }
    }

    Caption {
        pt: page.pt
        note: true
        text: Services.ChatBackground.error || "A custom image is dimmed a little so messages stay readable."
        color: Services.ChatBackground.error ? Look.destructive : Look.secondaryInk
    }

    component Choice: Column {
        id: choice
        property string label
        property bool selected
        property string source
        property bool dimmed: false
        signal clicked
        spacing: 8 * page.pt

        MouseArea {
            width: 140 * page.pt
            height: 250 * page.pt
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.clicked()

            ClippingRectangle {
                anchors.fill: parent
                radius: 18 * page.pt
                color: Look.groupFill

                Phone.ChatBackdrop {
                    anchors.fill: parent
                    visible: choice.source !== ""
                    source: choice.source
                    dimmed: choice.dimmed
                }

                Column {
                    visible: choice.source === ""
                    anchors.centerIn: parent
                    spacing: 8 * page.pt
                    Components.Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 28 * page.pt
                        height: width
                        action: "background"
                        iconColor: Look.secondaryInk
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Choose image"
                        color: Look.secondaryInk
                        font { family: Theme.Fonts.family; pixelSize: 13 * page.pt }
                    }
                }
            }

            Rectangle {
                anchors { fill: parent; margins: -4 * page.pt }
                radius: 22 * page.pt
                color: "transparent"
                border { width: 2.5 * page.pt; color: choice.selected ? Look.accent : "transparent" }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: choice.label
            color: choice.selected ? Look.accent : Look.ink
            font { family: Theme.Fonts.family; weight: choice.selected ? Font.DemiBold : Font.Normal; pixelSize: 15 * page.pt }
        }
    }
}
