import QtQuick
import Quickshell.Io

// Wired and Wi-Fi devices from NetworkManager, polled every 5 seconds while active.
Item {
    id: root

    property bool active: false
    // Each: { device, connection, state, connected, carrier, speed, address, gateway, dns }
    property var wired: []
    property var wireless: []
    property bool failed: false
    // At least one poll has finished.
    property bool loaded: false

    // The Wi-Fi device by interface name, or null.
    function wirelessDevice(name) {
        return wireless.find(device => device.device === name) ?? null
    }

    visible: false

    onActiveChanged: {
        if (active)
            failed = false
    }

    function parse(output) {
        const blocks = output.trim().split(/\n\s*\n/)
        const wired = []
        const wireless = []
        for (const block of blocks) {
            const fields = {}
            for (const line of block.split("\n")) {
                const separator = line.indexOf(":")
                if (separator < 0)
                    continue
                // IP4.ADDRESS[1], IP4.DNS[2], …: keep the first of each.
                const key = line.slice(0, separator).replace(/\[\d+\]$/, "")
                if (!(key in fields))
                    fields[key] = line.slice(separator + 1)
            }
            const type = fields["GENERAL.TYPE"]
            if (type !== "ethernet" && type !== "wifi")
                continue
            // "100 (connected)" → "connected"
            const state = (fields["GENERAL.STATE"] || "").replace(/^\d+\s*\(|\)$/g, "")
            const speed = Number.parseInt(fields["CAPABILITIES.SPEED"] || "")
            ;(type === "ethernet" ? wired : wireless).push({
                device: fields["GENERAL.DEVICE"] || "",
                connection: fields["GENERAL.CONNECTION"] || "",
                state: state,
                connected: state === "connected",
                carrier: fields["WIRED-PROPERTIES.CARRIER"] === "on",
                speed: Number.isFinite(speed) ? speed : 0,
                address: fields["IP4.ADDRESS"] || "",
                gateway: fields["IP4.GATEWAY"] || "",
                dns: fields["IP4.DNS"] || ""
            })
        }
        // Connected first, then ones with a cable in.
        wired.sort((a, b) => Number(b.connected) - Number(a.connected) || Number(b.carrier) - Number(a.carrier))
        root.wired = wired
        root.wireless = wireless
        loaded = true
    }

    Timer {
        interval: 5000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!query.running)
                query.running = true
        }
    }

    Process {
        id: query
        environment: ({ LC_ALL: "C" })
        command: ["nmcli", "-t", "-f",
            "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,WIRED-PROPERTIES.CARRIER,CAPABILITIES.SPEED,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS",
            "device", "show"]
        stdout: StdioCollector { id: queryOutput }
        stderr: StdioCollector {}
        onExited: code => {
            root.failed = code !== 0
            if (code === 0)
                root.parse(queryOutput.text)
            else
                root.loaded = true
        }
    }
}
