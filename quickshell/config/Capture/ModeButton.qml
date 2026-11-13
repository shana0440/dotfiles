import QtQuick
import "../Components" as Components
import "../Theme" as Theme

// A capture mode; recording modes carry a small record dot.
Components.IconButton {
    id: root

    property bool recording: false

    implicitWidth: 44
    implicitHeight: 40
    iconSize: 22

    Rectangle {
        visible: root.recording
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        width: 8
        height: 8
        radius: 4
        color: Theme.Colors.error
    }
}
