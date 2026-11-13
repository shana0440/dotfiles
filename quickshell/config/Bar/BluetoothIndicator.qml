import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Rectangle {
    id: root

    signal clicked()

    readonly property var connected: Services.Bluetooth.connectedDevices
    readonly property string statusText: !Services.Bluetooth.available ? "No Bluetooth adapter"
        : !Services.Bluetooth.enabled ? "Bluetooth off"
        : connected.length === 1 ? "Bluetooth: " + connected[0].name
        : connected.length > 1 ? "Bluetooth: " + connected.length + " devices connected"
        : "Bluetooth on"

    width: 40
    height: 32
    radius: 8
    color: mouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent
    Accessible.role: Accessible.Button
    Accessible.name: statusText

    Components.Icon {
        anchors.centerIn: parent
        action: !Services.Bluetooth.enabled ? "bluetoothOff"
            : root.connected.length > 0 ? "bluetoothConnected"
            : Services.Bluetooth.discovering ? "bluetoothSearching" : "bluetooth"
        opacity: Services.Bluetooth.enabled ? 1 : 0.5
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Components.Tooltip {
        text: root.statusText
        shown: mouse.containsMouse
    }
}
