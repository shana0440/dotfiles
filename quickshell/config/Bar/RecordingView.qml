import QtQuick
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    property int elapsedSeconds: 0
    property bool stopping: false
    readonly property string elapsedText: {
        const total = Math.max(0, elapsedSeconds)
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor(total / 60) % 60
        const seconds = total % 60
        const clock = String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0")
        return hours > 0 ? String(hours).padStart(2, "0") + ":" + clock : clock
    }
    signal stopRequested()

    implicitWidth: 300
    implicitHeight: 32

    Item {
        id: details
        x: 12
        width: stopButton.x - x - 8
        height: parent.height
        Accessible.role: Accessible.StaticText
        Accessible.name: "Screen Recording, " + root.elapsedText

        Row {
            anchors.fill: parent
            spacing: 8

            Rectangle {
                id: recordingDot
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: width / 2
                color: Theme.Colors.accent
            }

            Text {
                id: elapsedTime
                height: parent.height
                text: root.elapsedText
                color: Theme.Colors.accent
                font.family: "monospace"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                width: parent.width - recordingDot.width - elapsedTime.width - 2 * parent.spacing
                height: parent.height
                text: "Screen Recording"
                color: Theme.Colors.foreground
                font.pixelSize: 13
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Components.IconButton {
        id: stopButton
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: height / 2
        border.width: 1
        border.color: Theme.Colors.foreground
        icon: "stop"
        iconSize: 14
        iconFilled: true
        iconColor: Theme.Colors.accent
        tooltip: root.stopping ? "Finishing recording…" : "Stop recording"
        enabled: !root.stopping
        onClicked: root.stopRequested()
    }
}
