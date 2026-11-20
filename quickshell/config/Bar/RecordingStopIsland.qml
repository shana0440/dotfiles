import QtQuick
import "../Components" as Components
import "../Theme" as Theme

Components.Surface {
    id: root

    property bool stopping: false
    signal stopRequested()

    implicitWidth: 32
    implicitHeight: implicitWidth
    radius: height / 2

    Components.IconButton {
        anchors.fill: parent
        radius: root.radius
        iconSize: 0
        tooltip: root.stopping ? "Finishing recording…" : "Stop recording"
        enabled: !root.stopping
        onClicked: root.stopRequested()

        Rectangle {
            anchors.centerIn: parent
            width: 24
            height: width
            radius: width / 2
            color: Theme.Colors.transparent
            border.width: 1.5
            border.color: Theme.Colors.foreground

            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: width
                radius: 2
                color: Theme.Colors.recording
            }
        }
    }
}
