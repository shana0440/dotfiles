import QtQuick
import Quickshell.Io

// Network devices from NetworkManager, polled every 5 seconds while active.
Item {
    id: root

    property bool active: false
    // Ethernet, Wi-Fi, VPN tunnels and WireGuard. Each:
    // { device, type, kind, connection, state, connected, carrier, speed,
    //   address, gateway, dns, defaultMetric }
    property var devices: []
    property bool failed: false
    // At least one poll has finished.
    property bool loaded: false
    // The connected device whose default route wins (lowest metric), or null.
    readonly property var primary: {
        const routed = devices.filter(device => device.connected && device.defaultMetric !== null)
        return routed.sort((a, b) => a.defaultMetric - b.defaultMetric)[0] ?? null
    }

    readonly property var shownTypes: ["ethernet", "wifi", "tun", "wireguard"]

    visible: false

    onActiveChanged: {
        if (active)
            failed = false
    }

    function find(name) {
        return devices.find(device => device.device === name) ?? null
    }

    function kindOf(type, name) {
        if (type === "ethernet")
            return "Ethernet"
        if (type === "wifi")
            return "Wi-Fi"
        if (type === "wireguard")
            return "WireGuard"
        return name.startsWith("tailscale") ? "Tailscale" : "VPN"
    }

    function parse(output) {
        const parsed = []
        for (const block of output.trim().split(/\n\s*\n/)) {
            const fields = {}
            let defaultMetric = null
            for (const line of block.split("\n")) {
                const separator = line.indexOf(":")
                if (separator < 0)
                    continue
                const key = line.slice(0, separator).replace(/\[\d+\]$/, "")
                const value = line.slice(separator + 1)
                // "dst = 0.0.0.0/0, nh = 192.168.1.1, mt = 100"
                if (key === "IP4.ROUTE") {
                    const route = value.match(/dst = 0\.0\.0\.0\/0,.*mt = (\d+)/)
                    if (route)
                        defaultMetric = Math.min(defaultMetric ?? Infinity, Number(route[1]))
                    continue
                }
                // IP4.ADDRESS[1], IP4.DNS[2], …: keep the first of each.
                if (!(key in fields))
                    fields[key] = value
            }
            const type = fields["GENERAL.TYPE"]
            if (!shownTypes.includes(type))
                continue
            const name = fields["GENERAL.DEVICE"] || ""
            // "100 (connected)", "100 (connected (externally))" → "connected"
            const state = (fields["GENERAL.STATE"] || "").replace(/^\d+\s*\(/, "").replace(/\)$/, "").replace(/ \(externally\)$/, "")
            const speed = Number.parseInt(fields["CAPABILITIES.SPEED"] || "")
            parsed.push({
                device: name,
                type: type,
                kind: kindOf(type, name),
                connection: fields["GENERAL.CONNECTION"] || "",
                state: state,
                connected: state === "connected",
                carrier: fields["WIRED-PROPERTIES.CARRIER"] === "on",
                speed: Number.isFinite(speed) ? speed : 0,
                address: (fields["IP4.ADDRESS"] || "").replace(/\/\d+$/, ""),
                gateway: fields["IP4.GATEWAY"] || "",
                dns: fields["IP4.DNS"] || "",
                defaultMetric: defaultMetric
            })
        }
        devices = parsed
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
            "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,WIRED-PROPERTIES.CARRIER,CAPABILITIES.SPEED,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP4.ROUTE",
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
