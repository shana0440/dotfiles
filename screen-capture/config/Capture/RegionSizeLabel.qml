import QtQuick
import "../Theme" as Theme

Rectangle {
    id: root

    property int regionWidth: 0
    property int regionHeight: 0
    property bool recording: false

    implicitWidth: content.implicitWidth + 16
    implicitHeight: content.implicitHeight + 12
    radius: 6
    color: Theme.Colors.background

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.regionWidth + " × " + root.regionHeight
            color: Theme.Colors.foreground
            font.pixelSize: 12
        }
        Text {
            text: root.recording ? "Enter to record · Esc to cancel" : "Enter to capture · Esc to cancel"
            color: Theme.Colors.foreground
            opacity: 0.65
            font.pixelSize: 11
        }
    }
}
