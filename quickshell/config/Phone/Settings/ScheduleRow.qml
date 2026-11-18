import QtQuick
import "../../Theme" as Theme
import "../../Components" as Components
import "../../Services" as Services

Item {
    id: row

    required property var modelData
    required property int index
    property real pt: 1
    readonly property bool changing: Services.Mei.changingSchedule === modelData.name
    readonly property string when: modelData.spec.daily_at !== undefined
        ? "Daily at " + modelData.spec.daily_at
        : modelData.spec.every_minutes === 1 ? "Every minute" : "Every " + modelData.spec.every_minutes + " minutes"
    property bool wanted: modelData.enabled
    property bool confirming: false

    function nextRun(ms) {
        const due = new Date(ms)
        const today = new Date().toDateString() === due.toDateString()
        return Qt.formatDateTime(due, today ? "hh:mm" : "ddd hh:mm")
    }

    width: parent.width
    height: 60 * pt

    Rectangle {
        visible: row.index > 0
        anchors { top: parent.top; left: parent.left; leftMargin: 16 * row.pt; right: parent.right }
        height: 1
        color: Look.separator
    }

    Column {
        anchors { left: parent.left; leftMargin: 16 * row.pt; right: controls.left; rightMargin: 12 * row.pt; verticalCenter: parent.verticalCenter }
        spacing: 2 * row.pt
        Text {
            width: parent.width
            text: row.modelData.name
            elide: Text.ElideRight
            color: Look.ink
            font { family: Theme.Fonts.family; pixelSize: 17 * row.pt }
        }
        Text {
            width: parent.width
            text: row.when + (row.modelData.enabled && row.modelData.dueAt ? " · next " + row.nextRun(row.modelData.dueAt) : "")
            elide: Text.ElideRight
            color: Look.secondaryInk
            font { family: Theme.Fonts.family; pixelSize: 13 * row.pt }
        }
    }

    Row {
        id: controls
        anchors { right: parent.right; rightMargin: 12 * row.pt; verticalCenter: parent.verticalCenter }
        spacing: 14 * row.pt

        Toggle {
            visible: !row.confirming
            anchors.verticalCenter: parent.verticalCenter
            pt: row.pt
            on: row.changing ? row.wanted : row.modelData.enabled
            busy: Services.Mei.changingSchedule !== ""
            onToggled: {
                row.wanted = !row.modelData.enabled
                Services.Mei.changeSchedule(row.wanted ? "enable" : "disable", row.modelData.name)
            }
        }

        MouseArea {
            visible: !row.confirming
            anchors.verticalCenter: parent.verticalCenter
            width: 26 * row.pt
            height: width
            enabled: Services.Mei.changingSchedule === ""
            cursorShape: Qt.PointingHandCursor
            onClicked: row.confirming = true
            Components.Icon {
                anchors.centerIn: parent
                width: 22 * row.pt
                height: width
                action: "remove"
                iconColor: parent.pressed ? Look.hairline : Look.secondaryInk
            }
        }

        TextButton {
            visible: row.confirming
            anchors.verticalCenter: parent.verticalCenter
            pt: row.pt
            label: "Cancel"
            onClicked: row.confirming = false
        }

        Rectangle {
            visible: row.confirming
            anchors.verticalCenter: parent.verticalCenter
            width: removeLabel.width + 24 * row.pt
            height: 32 * row.pt
            radius: height / 2
            color: removeArea.pressed ? Qt.darker(Look.destructive, 1.15) : Look.destructive
            Text {
                id: removeLabel
                anchors.centerIn: parent
                text: row.changing ? "Removing…" : "Remove"
                color: "white"
                font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 15 * row.pt }
            }
            MouseArea {
                id: removeArea
                anchors.fill: parent
                enabled: Services.Mei.changingSchedule === ""
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Mei.changeSchedule("remove", row.modelData.name)
            }
        }
    }
}
