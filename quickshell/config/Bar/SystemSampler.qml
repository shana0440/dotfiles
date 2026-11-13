import QtQuick
import Quickshell.Io

// Polls system-status-snapshot every 2 seconds while active and derives CPU usage
// and transfer rates from consecutive snapshots.
Item {
    id: root

    property bool active: false
    property var snapshot: null
    property var cpuUsage: null
    property var networkRates: []
    property var diskRates: []
    property bool failed: false
    readonly property var memory: snapshot ? snapshot.memory : null
    readonly property var temperature: snapshot ? snapshot.temperature : null
    readonly property var gpus: snapshot ? snapshot.gpus || [] : []

    visible: false

    onActiveChanged: {
        if (active) {
            clearReadings()
            failed = false
        }
    }

    function clearReadings() {
        snapshot = null
        cpuUsage = null
        networkRates = []
        diskRates = []
    }

    function rates(current, previous, seconds, incomingKey, outgoingKey) {
        return current.map(device => {
            const old = previous.find(item => item.id === device.id)
            const perSecond = key => old && seconds > 0 && device[key] >= old[key] ? (device[key] - old[key]) / seconds : null
            return {
                label: device.label,
                incoming: perSecond(incomingKey),
                outgoing: perSecond(outgoingKey)
            }
        })
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!sample.running) {
                sample.startedSuccessfully = false
                sample.running = true
            }
        }
    }

    Process {
        id: sample
        property bool startedSuccessfully: false
        command: ["system-status-snapshot"]
        onStarted: startedSuccessfully = true
        stdout: StdioCollector {
            id: output
        }
        onExited: code => {
            if (!root.active)
                return
            root.failed = code !== 0
            if (!root.failed) {
                try {
                    const next = JSON.parse(output.text)
                    const previous = root.snapshot
                    const delta = previous ? next.cpu.total - previous.cpu.total : 0
                    const seconds = previous ? next.monotonic - previous.monotonic : 0
                    root.cpuUsage = delta > 0 ? Math.max(0, Math.min(1, 1 - (next.cpu.idle - previous.cpu.idle) / delta)) : null
                    root.networkRates = root.rates(next.network || [], previous ? previous.network || [] : [], seconds, "rx", "tx")
                    root.diskRates = root.rates(next.disks || [], previous ? previous.disks || [] : [], seconds, "read", "write")
                    root.snapshot = next
                } catch (error) {
                    // Invalidate the UI at the subprocess boundary, then report the bad snapshot.
                    root.failed = true
                    root.clearReadings()
                    throw new Error("Invalid system-status snapshot: " + error)
                }
            }
            if (root.failed)
                root.clearReadings()
        }
        onRunningChanged: {
            // FailedToStart emits runningChanged but not exited; old stdout is irrelevant.
            if (!running && !startedSuccessfully && root.active) {
                root.failed = true
                root.clearReadings()
            }
        }
    }
}
