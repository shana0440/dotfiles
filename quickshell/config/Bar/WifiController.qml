import QtQuick
import Quickshell.Io

// Wi-Fi through NetworkManager: scans while active, connects and disconnects.
Item {
    id: root

    property bool active: false
    property string message: ""
    readonly property alias networks: networks
    readonly property bool scanning: scan.running
    readonly property bool connecting: connectProcess.running
    readonly property bool busy: connectProcess.running || disconnectProcess.running
    property string pendingPassword: ""
    // A connect or disconnect succeeded.
    signal connectionChanged()

    visible: false

    onActiveChanged: {
        pendingPassword = ""
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

    // A blank password uses saved credentials.
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
        // Leaving a network is disruptive; record who asked, to trace surprises.
        console.warn("Wi-Fi disconnect requested for", device)
        console.trace()
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
        // Pass passwords through stdin to keep them out of process listings.
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
