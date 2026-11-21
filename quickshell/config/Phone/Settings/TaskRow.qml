import QtQuick
import "../../Theme" as Theme
import "../../Components" as Components
import "../../Services" as Services

Item {
    id: row

    required property var modelData
    required property int index
    property real pt: 1
    property real now: Date.now()
    property bool confirming: false
    readonly property bool cancelling: Services.Mei.cancellingTask === modelData.id
    readonly property bool working: modelData.status === "running"
    readonly property bool reportingBack: working && modelData.step !== "background" && modelData.step !== "script"
    readonly property string what: {
        const payload = modelData.payload
        if (modelData.type === "task.script") return "Watch " + payload.command
        const line = payload.text.split("\n")[0]
        return payload.say ? "Say “" + line + "”" : line
    }
    readonly property string progress: {
        const task = modelData
        if (reportingBack) return "Reporting back"
        if (working && task.step === "script") return "Running for " + elapsed(now - task.startedAt)
        if (working) return "Running since " + clock(task.startedAt)
            + " · stops at " + clock(task.startedAt + Services.Mei.taskTimeoutMinutes * 60000)
        if (task.runAt !== null && task.runAt > now) return "Waiting until " + clock(task.runAt)
        return "Queued"
    }

    function clock(ms) {
        const today = new Date(now).toDateString() === new Date(ms).toDateString()
        return Qt.formatDateTime(new Date(ms), today ? "hh:mm" : "ddd hh:mm")
    }

    function elapsed(ms) {
        const minutes = Math.floor(ms / 60000)
        if (minutes < 1) return Math.max(0, Math.round(ms / 1000)) + "s"
        if (minutes < 60) return minutes + "m"
        const hours = Math.floor(minutes / 60)
        return hours < 24 ? hours + "h " + minutes % 60 + "m" : Math.floor(hours / 24) + "d " + hours % 24 + "h"
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
            text: row.what
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            color: Look.ink
            font { family: Theme.Fonts.family; pixelSize: 17 * row.pt }
        }
        Text {
            width: parent.width
            text: row.progress
            elide: Text.ElideRight
            color: row.working ? Look.switchOn : Look.secondaryInk
            font { family: Theme.Fonts.family; pixelSize: 13 * row.pt }
        }
    }

    Row {
        id: controls
        anchors { right: parent.right; rightMargin: 12 * row.pt; verticalCenter: parent.verticalCenter }
        spacing: 14 * row.pt

        MouseArea {
            visible: !row.confirming && !row.reportingBack
            anchors.verticalCenter: parent.verticalCenter
            width: 26 * row.pt
            height: width
            enabled: Services.Mei.cancellingTask === 0
            cursorShape: Qt.PointingHandCursor
            onClicked: row.confirming = true
            Components.Icon {
                anchors.centerIn: parent
                width: 22 * row.pt
                height: width
                action: "close"
                iconColor: parent.pressed ? Look.hairline : Look.secondaryInk
            }
        }

        TextButton {
            visible: row.confirming
            anchors.verticalCenter: parent.verticalCenter
            pt: row.pt
            label: "Keep"
            onClicked: row.confirming = false
        }

        Rectangle {
            visible: row.confirming
            anchors.verticalCenter: parent.verticalCenter
            width: stopLabel.width + 24 * row.pt
            height: 32 * row.pt
            radius: height / 2
            color: stopArea.pressed ? Qt.darker(Look.destructive, 1.15) : Look.destructive
            Text {
                id: stopLabel
                anchors.centerIn: parent
                text: row.cancelling ? "Stopping…" : "Stop"
                color: "white"
                font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 15 * row.pt }
            }
            MouseArea {
                id: stopArea
                anchors.fill: parent
                enabled: Services.Mei.cancellingTask === 0
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Mei.cancelTask(row.modelData.id)
            }
        }
    }
}
