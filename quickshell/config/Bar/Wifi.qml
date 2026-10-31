import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme" as Theme
import "../Components" as Components

Rectangle {
    id: root

    signal clicked()

    property bool available: false
    property bool radioEnabled: false
    property bool connected: false
    property string ssid: ""
    property int strength: 0
    readonly property string statusText: !available ? "NetworkManager unavailable"
        : !radioEnabled ? "Wi-Fi disabled"
        : connected ? ssid + " (" + strength + "%)" : "Wi-Fi disconnected"

    width: 40
    height: 32
    radius: 8
    color: wifiMouse.containsMouse ? Theme.Colors.activeWorkspace : Theme.Colors.transparent
    Accessible.role: Accessible.Button
    Accessible.name: statusText

    function refreshStatus() {
        if (!status.running)
            status.running = true
    }

    function applyStatus(output) {
        const [radioState, ...accessPoints] = output.trim().split("\n")
        const activePrefix = "yes:"
        available = radioState === "enabled" || radioState === "disabled"
        radioEnabled = radioState === "enabled"
        connected = false
        ssid = ""
        strength = 0
        for (const line of accessPoints) {
            if (!line.startsWith(activePrefix))
                continue
            const signalSeparator = line.lastIndexOf(":")
            ssid = line.slice(activePrefix.length, signalSeparator) || "Hidden network"
            strength = Number(line.slice(signalSeparator + 1)) || 0
            connected = true
            break
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!status.running)
                status.running = true
        }
    }

    Process {
        id: status
        command: ["sh", "-c", "export LC_ALL=C; nmcli -t -f WIFI general && nmcli -t -e no -f ACTIVE,SSID,SIGNAL device wifi list --rescan no"]
        onExited: code => {
            if (code !== 0) {
                root.available = false
                root.connected = false
            }
        }
        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(text)
        }
    }

    Components.Icon {
        anchors.centerIn: parent
        action: !root.connected ? "wifiOff" : root.strength >= 67 ? "wifi"
            : root.strength >= 34 ? "wifiHigh" : "wifiLow"
        opacity: root.radioEnabled ? 1 : 0.5
    }

    MouseArea {
        id: wifiMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Components.Tooltip {
        text: root.statusText
        shown: wifiMouse.containsMouse
    }
}
