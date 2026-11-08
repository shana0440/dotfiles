pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth as QsBluetooth

// BlueZ state comes from Quickshell.Bluetooth; pairing prompts come from the
// bluetooth-pairing-agent process, since Quickshell does not register an agent.
Singleton {
    id: root

    readonly property var adapter: QsBluetooth.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property var devices: adapter?.devices.values ?? []
    readonly property var connectedDevices: devices.filter(device => device.connected)
    // Current agent prompt, or null. See scripts/bluetooth_agent.py for fields.
    property var request: null
    readonly property bool agentRunning: agent.running

    function setEnabled(value) {
        if (adapter)
            adapter.enabled = value
    }

    function setDiscovering(value) {
        if (adapter && adapter.enabled && adapter.discovering !== value)
            adapter.discovering = value
    }

    function respond(accept, value) {
        if (!request)
            return
        if (request.id !== undefined && !request.type.startsWith("display-"))
            agent.write(JSON.stringify({ id: request.id, accept: accept, value: String(value ?? "") }) + "\n")
        request = null
    }

    Process {
        id: agent
        command: ["bluetooth-pairing-agent"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data)
                    root.request = message.type === "cancel" ? null : message
                } catch (error) {
                    console.warn("Invalid Bluetooth agent message:", error)
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                root.request = null
                retry.restart()
            }
        }
    }

    Timer {
        id: retry
        interval: 3000
        onTriggered: agent.running = true
    }

    // Passkey displays have no reply; clear them once pairing finishes.
    Connections {
        target: root.request?.type?.startsWith("display-") ? root.devices.find(device => device.dbusPath === root.request.device) ?? null : null
        function onPairingChanged() {
            if (!target.pairing)
                root.request = null
        }
    }
}
