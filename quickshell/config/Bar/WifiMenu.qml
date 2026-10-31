import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    property bool active: false
    signal closeRequested()
    signal connectionChanged()
    property string selectedSsid: ""
    property string message: ""
    property string secret: ""
    readonly property bool busy: connectProcess.running || disconnectProcess.running

    implicitWidth: 340
    implicitHeight: content.implicitHeight + 24
    focus: active

    onActiveChanged: {
        password.text = ""
        secret = ""
        selectedSsid = ""
        if (active)
            refresh()
    }

    function refresh() {
        if (scan.running || busy)
            return
        message = ""
        scan.running = true
    }

    function fields(line) {
        const result = []
        let field = ""
        let escaped = false
        for (const char of line) {
            if (escaped) {
                field += char
                escaped = false
            } else if (char === "\\") {
                escaped = true
            } else if (char === ":") {
                result.push(field)
                field = ""
            } else {
                field += char
            }
        }
        result.push(field)
        return result
    }

    function loadNetworks(output) {
        const unique = new Map()
        for (const line of output.trim().split("\n")) {
            const parts = fields(line)
            if (parts.length < 4 || !parts[1])
                continue
            const network = {
                ssid: parts[1], active: parts[0] === "yes",
                strength: Number(parts[2]) || 0, security: parts[3], device: parts[4] || ""
            }
            const previous = unique.get(network.ssid)
            if (!previous || network.active || (!previous.active && network.strength > previous.strength))
                unique.set(network.ssid, network)
        }
        const sorted = Array.from(unique.values()).sort((a, b) => Number(b.active) - Number(a.active) || b.strength - a.strength)
        networks.clear()
        for (const network of sorted)
            networks.append(network)
        if (!networks.count)
            message = "No networks found. Check that Wi-Fi is enabled."
    }

    function selectNetwork(ssid, security) {
        selectedSsid = ssid
        password.text = ""
        message = ""
        if (!security || security === "--")
            connectSelected()
        else
            Qt.callLater(() => password.forceActiveFocus())
    }

    function connectSelected() {
        if (!selectedSsid || busy)
            return
        secret = password.text
        password.text = ""
        message = "Connecting to " + selectedSsid + "…"
        connectProcess.stdinEnabled = true
        connectProcess.command = ["nmcli", "--ask", "--wait", "30", "device", "wifi", "connect", selectedSsid]
        connectProcess.running = true
    }

    function disconnectNetwork(device) {
        if (!device || busy)
            return
        selectedSsid = ""
        password.text = ""
        message = "Disconnecting…"
        disconnectProcess.command = ["nmcli", "--wait", "15", "device", "disconnect", device]
        disconnectProcess.running = true
    }

    ListModel { id: networks }

    Process {
        id: scan
        environment: ({ LC_ALL: "C" })
        command: ["nmcli", "-t", "-e", "yes", "-f", "ACTIVE,SSID,SIGNAL,SECURITY,DEVICE", "device", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector { id: scanOutput }
        stderr: StdioCollector {}
        onExited: code => {
            if (code === 0)
                root.loadNetworks(scanOutput.text)
            else
                root.message = "Unable to list Wi-Fi networks. Try refreshing."
        }
    }

    Process {
        id: connectProcess
        environment: ({ LC_ALL: "C" })
        stdinEnabled: true
        // Send secrets through stdin, never through command-line arguments.
        onStarted: {
            if (root.secret)
                write(root.secret + "\n")
            root.secret = ""
            stdinEnabled = false
        }
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            root.secret = ""
            if (code === 0) {
                root.selectedSsid = ""
                root.message = "Connected."
                root.connectionChanged()
                root.refresh()
            } else {
                root.message = "Connection failed. Check the password or use advanced settings."
            }
        }
    }

    Process {
        id: disconnectProcess
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            if (code === 0) {
                root.message = "Disconnected."
                root.connectionChanged()
                Qt.callLater(() => root.refresh())
            } else {
                root.message = "Unable to disconnect. Try refreshing or use advanced settings."
            }
        }
    }

    component Button: Rectangle {
        property string label: ""
        signal clicked()
        implicitWidth: buttonText.implicitWidth + 20
        implicitHeight: 30
        radius: 6
        color: buttonMouse.containsMouse ? Theme.Colors.activeWorkspace : Theme.Colors.transparent
        opacity: enabled ? 1 : 0.4
        Accessible.role: Accessible.Button
        Accessible.name: label

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: parent.label
            color: Theme.Colors.foreground
            font.pixelSize: 13
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.Colors.background

        MouseArea { anchors.fill: parent }

        Column {
            id: content
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8
            focus: root.active
            Keys.onEscapePressed: root.closeRequested()

            Row {
                width: parent.width
                height: 30

                Text {
                    width: parent.width - refreshButton.width - closeButton.width
                    height: parent.height
                    text: "Wi-Fi"
                    color: Theme.Colors.foreground
                    font.pixelSize: 16
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
                Button {
                    id: refreshButton
                    label: scan.running ? "Scanning…" : "Refresh"
                    enabled: !scan.running && !root.busy
                    onClicked: root.refresh()
                }
                Button {
                    id: closeButton
                    label: "×"
                    onClicked: root.closeRequested()
                }
            }

            Text {
                width: parent.width
                text: root.message
                visible: text.length > 0
                wrapMode: Text.Wrap
                color: Theme.Colors.foreground
                opacity: 0.7
                font.pixelSize: 12
            }

            ListView {
                id: networkList
                width: parent.width
                height: 220
                clip: true
                spacing: 4
                model: networks
                enabled: !root.busy

                delegate: Rectangle {
                    required property string ssid
                    required property bool active
                    required property int strength
                    required property string security
                    required property string device

                    width: networkList.width
                    height: 48
                    radius: 6
                    color: active || networkMouse.containsMouse ? Theme.Colors.activeWorkspace : Theme.Colors.transparent

                    Components.Icon {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        action: parent.strength >= 67 ? "wifi" : parent.strength >= 34 ? "wifiHigh" : "wifiLow"
                    }

                    Column {
                        x: 38
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 38 - (active ? disconnectButton.width + 16 : 52)
                        spacing: 2

                        Text {
                            width: parent.width
                            text: ssid
                            elide: Text.ElideRight
                            color: Theme.Colors.foreground
                            font.pixelSize: 13
                        }
                        Text {
                            width: parent.width
                            text: active ? "Connected" : (!security || security === "--" ? "Open" : security)
                            elide: Text.ElideRight
                            color: Theme.Colors.foreground
                            opacity: 0.6
                            font.pixelSize: 11
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: strength + "%"
                        visible: !active
                        color: Theme.Colors.foreground
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: networkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!active)
                                root.selectNetwork(ssid, security)
                        }
                    }

                    Button {
                        id: disconnectButton
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Disconnect"
                        visible: active
                        onClicked: root.disconnectNetwork(device)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6
                visible: root.selectedSsid.length > 0

                Text {
                    width: parent.width
                    text: root.selectedSsid
                    elide: Text.ElideRight
                    color: Theme.Colors.foreground
                    font.pixelSize: 13
                }
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: Theme.Colors.activeWorkspace

                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.margins: 8
                        echoMode: TextInput.Password
                        enabled: !root.busy
                        color: Theme.Colors.foreground
                        font.pixelSize: 13
                        selectByMouse: true
                        clip: true
                        onAccepted: root.connectSelected()
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "Password (blank uses saved credentials)"
                        visible: !password.text && !password.activeFocus
                        color: Theme.Colors.foreground
                        opacity: 0.5
                        font.pixelSize: 11
                    }
                }
                Row {
                    spacing: 8
                    Button {
                        label: "Cancel"
                        enabled: !root.busy
                        onClicked: {
                            root.selectedSsid = ""
                            password.text = ""
                        }
                    }
                    Button {
                        label: connectProcess.running ? "Connecting…" : "Connect"
                        enabled: !root.busy
                        onClicked: root.connectSelected()
                    }
                }
            }

            Button {
                label: "Advanced settings…"
                enabled: !root.busy
                onClicked: {
                    root.closeRequested()
                    Quickshell.execDetached(["kitty", "--class", "wifi-settings", "-e", "nmtui"])
                }
            }
        }
    }
}
