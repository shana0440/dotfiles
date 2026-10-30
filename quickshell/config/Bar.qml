import QtQuick
import Quickshell

PanelWindow {
    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 32
    color: "#000000"

    Text {
        anchors.centerIn: parent
        text: "Hello, Quickshell!"
        color: "#cdd6f4"
        font.pixelSize: 14
    }
}
