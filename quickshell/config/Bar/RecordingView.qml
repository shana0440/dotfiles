import QtQuick
import "../Theme" as Theme

Item {
    id: root

    property int elapsedSeconds: 0
    readonly property string elapsedText: {
        const total = Math.max(0, elapsedSeconds)
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor(total / 60) % 60
        const seconds = total % 60
        const clock = String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0")
        return hours > 0 ? String(hours).padStart(2, "0") + ":" + clock : clock
    }

    implicitWidth: 300
    implicitHeight: 32
    Accessible.role: Accessible.StaticText
    Accessible.name: "Screen Recording, " + elapsedText

    function centeredTextY(baseline, bounds) {
        return height / 2 - baseline - (bounds.y + bounds.height / 2)
    }

    Rectangle {
        id: recordingDot
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: width
        radius: width / 2
        color: Theme.Colors.recording
    }

    Text {
        id: recordingLabel
        anchors.left: recordingDot.right
        anchors.leftMargin: 8
        anchors.right: elapsedTime.left
        anchors.rightMargin: 12
        y: root.centeredTextY(baselineOffset, labelMetrics.tightBoundingRect)
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        font.pixelSize: 13
        text: "Screen Recording"
        color: Theme.Colors.foreground
        elide: Text.ElideRight

        TextMetrics {
            id: labelMetrics
            font: recordingLabel.font
            text: recordingLabel.text
        }
    }

    Text {
        id: elapsedTime
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: root.centeredTextY(baselineOffset, timerMetrics.tightBoundingRect)
        font.family: "monospace"
        font.weight: Theme.Fonts.weight
        font.pixelSize: 13
        text: root.elapsedText
        color: Theme.Colors.foreground

        TextMetrics {
            id: timerMetrics
            font: elapsedTime.font
            text: "00:00"
        }
    }
}
