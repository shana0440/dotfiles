import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool active: false
    property string message: ""
    property bool enabled: true
    property bool loaded: false
    property var current: null
    readonly property alias networks: networks
    readonly property bool scanning: scan.running
    readonly property bool connecting: connectProcess.running
    readonly property bool switching: radioSwitch.running
    readonly property bool busy: connectProcess.running || disconnectProcess.running || radioSwitch.running
    property string pendingPassword: ""
    signal connectionChanged()

    visible: false

    onActiveChanged: pendingPassword = ""

    function refresh() {
        if (scan.running || busy)
            return
        message = ""
        if (!enabled) {
            networks.clear()
            return
        }
        scan.running = true
    }

    function update() {
        if (!radio.running)
            radio.running = true
        if (!currentQuery.running)
            currentQuery.running = true
    }

    function setEnabled(on) {
        if (radioSwitch.running)
            return
        enabled = on
        message = ""
        if (!on) {
            networks.clear()
            current = null
        }
        radioSwitch.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        radioSwitch.running = true
    }

    function loadCurrent(output) {
        for (const line of output.trim().split("\n")) {
            const parts = fields(line)
            if (parts[0] === "yes" && parts[1]) {
                current = { ssid: parts[1], strength: Number(parts[2]) || 0 }
                return
            }
        }
        current = null
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
        current = sorted[0]?.active ? { ssid: sorted[0].ssid, strength: sorted[0].strength } : null
        if (!networks.count)
            message = "No networks found."
    }

    function connect(ssid, password) {
        if (!ssid || busy)
            return
        pendingPassword = password
        message = "Connecting to " + ssid + "…"
        connectProcess.stdinEnabled = true
        connectProcess.command = ["nmcli", "--ask", "--wait", "30", "device", "wifi", "connect", ssid]
        connectProcess.running = true
    }

    function disconnect(device) {
        if (!device || busy)
            return
        message = "Disconnecting…"
        disconnectProcess.command = ["nmcli", "--wait", "15", "device", "disconnect", device]
        disconnectProcess.running = true
    }

    ListModel { id: networks }

    Timer {
        interval: 5000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.update()
    }

    Process {
        id: radio
        environment: ({ LC_ALL: "C" })
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: StdioCollector { id: radioOutput }
        stderr: StdioCollector {}
        onExited: code => {
            if (code === 0 && !radioSwitch.running)
                root.enabled = radioOutput.text.trim() === "enabled"
            root.loaded = true
        }
    }

    Process {
        id: currentQuery
        environment: ({ LC_ALL: "C" })
        command: ["nmcli", "-t", "-e", "yes", "-f", "ACTIVE,SSID,SIGNAL", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector { id: currentOutput }
        stderr: StdioCollector {}
        onExited: code => {
            if (code === 0)
                root.loadCurrent(currentOutput.text)
        }
    }

    Process {
        id: radioSwitch
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            if (code !== 0)
                root.message = "Unable to turn Wi-Fi " + (root.enabled ? "on." : "off.")
            root.update()
            if (root.enabled)
                retryScan.restart()
        }
    }

    Timer {
        id: retryScan
        interval: 3000
        onTriggered: root.refresh()
    }

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
        onStarted: {
            if (root.pendingPassword)
                write(root.pendingPassword + "\n")
            root.pendingPassword = ""
            stdinEnabled = false
        }
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            root.pendingPassword = ""
            if (code === 0) {
                root.message = "Connected."
                root.connectionChanged()
                Qt.callLater(() => root.refresh())
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
}
