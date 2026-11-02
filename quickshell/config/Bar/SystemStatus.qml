import QtQuick
import Quickshell.Io
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    property bool active: false
    property var snapshot: null
    property var cpuUsage: null
    property var networkRates: []
    property var diskRates: []
    property real maximumHeight: 720
    property bool failed: false
    signal closeRequested

    implicitWidth: 380
    implicitHeight: Math.min(content.implicitHeight + 78, maximumHeight)
    readonly property var memory: snapshot ? snapshot.memory : null
    readonly property var temperature: snapshot ? snapshot.temperature : null
    readonly property color muted: "#9c9ca8"

    onActiveChanged: {
        if (active) {
            clearReadings()
            failed = false
            viewport.contentY = 0
        }
    }

    function clearReadings() {
        snapshot = null
        cpuUsage = null
        networkRates = []
        diskRates = []
    }

    function bytes(value) {
        const gib = value / (1024 * 1024 * 1024)
        return gib >= 1 ? gib.toFixed(1) + " GiB" : (value / (1024 * 1024)).toFixed(0) + " MiB"
    }

    function rate(value) {
        if (value === null)
            return "—"
        const units = ["B/s", "KiB/s", "MiB/s", "GiB/s"]
        let unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            unit++
        }
        return value.toFixed(unit ? 1 : 0) + " " + units[unit]
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

    function percent(value) {
        return Math.round(value * 100) + "%"
    }

    function uptime(seconds) {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor(seconds / 3600) % 24
        const minutes = Math.floor(seconds / 60) % 60
        return (days ? days + "d " : "") + hours + "h " + minutes + "m"
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

    component Meter: Rectangle {
        property real fraction: 0
        property color fillColor: Theme.Colors.accent
        height: 4
        radius: 2
        color: Theme.Colors.activeWorkspace

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.fraction))
            height: parent.height
            radius: parent.radius
            color: parent.fillColor
            Behavior on width {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    component Metric: Rectangle {
        property string label: ""
        property string value: ""
        property string detail: ""
        property real fraction: -1
        property bool warning: fraction >= 0.9
        width: (content.width - 10) / 2
        height: 108
        radius: 10
        color: "#202024"

        Column {
            x: 12
            y: 10
            width: parent.width - 24
            spacing: 6
            Text {
                text: label
                color: root.muted
                font.pixelSize: 12
            }
            Text {
                text: value
                color: warning ? "#fbbf24" : Theme.Colors.foreground
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: detail
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.muted
                font.pixelSize: 11
            }
            Meter {
                width: parent.width
                fraction: parent.parent.fraction
                visible: parent.parent.fraction >= 0
                fillColor: warning ? "#fbbf24" : Theme.Colors.accent
            }
        }
    }

    component Transfer: Rectangle {
        property string label: ""
        property string incomingLabel: ""
        property string outgoingLabel: ""
        property var incoming: null
        property var outgoing: null
        width: content.width
        height: 62
        radius: 10
        color: "#202024"

        Column {
            x: 12
            y: 10
            width: parent.width - 24
            spacing: 8
            Text {
                text: label
                color: root.muted
                font.pixelSize: 11
            }
            Row {
                width: parent.width
                Text {
                    width: parent.width / 2
                    text: incomingLabel + "  " + root.rate(incoming)
                    color: Theme.Colors.foreground
                    font.pixelSize: 12
                }
                Text {
                    text: outgoingLabel + "  " + root.rate(outgoing)
                    color: Theme.Colors.foreground
                    font.pixelSize: 12
                }
            }
        }
    }

    // Consume clicks inside the expanded island rather than dismissing it.
    MouseArea {
        anchors.fill: parent
    }

    Row {
        x: 16
        y: 16
        width: parent.width - 32
        height: 32
        spacing: 10

        Components.Icon {
            anchors.verticalCenter: parent.verticalCenter
            action: "systemStatus"
            iconColor: Theme.Colors.accent
        }
        Column {
            width: parent.width - 72
            spacing: 2
            Text {
                text: "System status"
                color: Theme.Colors.foreground
                font.pixelSize: 16
                font.bold: true
            }
            Text {
                text: root.failed ? "Unable to read system metrics" : "Live host metrics · every 2 seconds"
                color: root.failed ? "#fbbf24" : root.muted
                font.pixelSize: 10
            }
        }
        Components.IconButton {
            width: 32
            height: 32
            icon: "close"
            tooltip: "Close system status (Esc)"
            onClicked: root.closeRequested()
        }
    }

    Flickable {
        id: viewport
        x: 16
        y: 62
        width: parent.width - 32
        height: parent.height - y - 16
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            width: viewport.width
            spacing: 14

            Grid {
                columns: 2
                spacing: 10
                Metric {
                    label: "CPU"
                    value: root.cpuUsage !== null ? root.percent(root.cpuUsage) : "—"
                    detail: root.snapshot ? root.snapshot.cores + " logical cores" : "Waiting for sample"
                    fraction: root.cpuUsage !== null ? root.cpuUsage : -1
                }
                Metric {
                    label: "Memory"
                    value: root.memory ? root.percent(root.memory.used / root.memory.total) : "—"
                    detail: root.memory ? root.bytes(root.memory.used) + " / " + root.bytes(root.memory.total) : "Unavailable"
                    fraction: root.memory ? root.memory.used / root.memory.total : -1
                }
                Metric {
                    label: root.temperature && root.temperature.cpu ? "CPU temperature" : "Temperature"
                    value: root.temperature ? Math.round(root.temperature.celsius) + "°C" : "—"
                    detail: root.temperature ? root.temperature.label : "No readable sensor"
                    warning: root.temperature !== null && root.temperature.celsius >= 85
                }
                Metric {
                    label: "Swap"
                    value: root.memory ? (root.memory.swapTotal ? root.percent(root.memory.swapUsed / root.memory.swapTotal) : "Off") : "—"
                    detail: root.memory ? (root.memory.swapTotal ? root.bytes(root.memory.swapUsed) + " / " + root.bytes(root.memory.swapTotal) : "No swap configured") : "Unavailable"
                    fraction: root.memory && root.memory.swapTotal ? root.memory.swapUsed / root.memory.swapTotal : -1
                }
            }

            Column {
                width: parent.width
                spacing: 10
                Text {
                    text: "GPU"
                    color: root.muted
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
                Repeater {
                    model: root.snapshot ? root.snapshot.gpus || [] : []
                    delegate: Column {
                        required property var modelData
                        width: content.width
                        spacing: 8
                        Text {
                            width: parent.width
                            text: modelData.name
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: root.muted
                            font.pixelSize: 11
                        }
                        Grid {
                            columns: 2
                            spacing: 10
                            Metric {
                                height: 96
                                label: "GPU utilization"
                                value: modelData.usage !== null ? root.percent(modelData.usage) : "—"
                                detail: modelData.temperature !== null ? Math.round(modelData.temperature) + "°C · GPU temperature" : "Temperature unavailable"
                                fraction: modelData.usage !== null ? modelData.usage : -1
                                warning: fraction >= 0.9 || (modelData.temperature !== null && modelData.temperature >= 85)
                            }
                            Metric {
                                height: 96
                                label: "VRAM"
                                readonly property bool available: modelData.memoryUsed !== null && modelData.memoryTotal > 0
                                value: available ? root.percent(modelData.memoryUsed / modelData.memoryTotal) : "—"
                                detail: available ? root.bytes(modelData.memoryUsed) + " / " + root.bytes(modelData.memoryTotal) : "Dedicated VRAM unavailable"
                                fraction: available ? modelData.memoryUsed / modelData.memoryTotal : -1
                            }
                        }
                    }
                }
                Text {
                    visible: !root.snapshot || !(root.snapshot.gpus || []).length
                    text: root.snapshot ? "No supported GPU telemetry" : "Waiting for sample"
                    color: root.muted
                    font.pixelSize: 11
                }
            }

            Column {
                width: parent.width
                spacing: 10
                Text {
                    text: "NETWORK"
                    color: root.muted
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
                Repeater {
                    model: root.networkRates
                    delegate: Transfer {
                        required property var modelData
                        label: modelData.label
                        incomingLabel: "↓ Download"
                        outgoingLabel: "↑ Upload"
                        incoming: modelData.incoming
                        outgoing: modelData.outgoing
                    }
                }
                Text {
                    visible: !root.networkRates.length
                    text: root.snapshot ? "No active network interfaces" : "Waiting for sample"
                    color: root.muted
                    font.pixelSize: 11
                }
            }

            Column {
                width: parent.width
                spacing: 10
                Text {
                    text: "DISK ACTIVITY"
                    color: root.muted
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
                Repeater {
                    model: root.diskRates
                    delegate: Transfer {
                        required property var modelData
                        label: modelData.label
                        incomingLabel: "Read"
                        outgoingLabel: "Write"
                        incoming: modelData.incoming
                        outgoing: modelData.outgoing
                    }
                }
                Text {
                    visible: !root.diskRates.length
                    text: root.snapshot ? "No physical disk counters available" : "Waiting for sample"
                    color: root.muted
                    font.pixelSize: 11
                }
            }

            Column {
                width: parent.width
                spacing: 10
                Text {
                    text: "STORAGE"
                    color: root.muted
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
                Repeater {
                    model: root.snapshot ? root.snapshot.storage : []
                    delegate: Column {
                        required property var modelData
                        width: content.width
                        spacing: 6
                        Row {
                            width: parent.width
                            Text {
                                width: parent.width - 55
                                text: modelData.label + " · " + modelData.path
                                textFormat: Text.PlainText
                                elide: Text.ElideMiddle
                                color: Theme.Colors.foreground
                                font.pixelSize: 12
                            }
                            Text {
                                width: 55
                                text: root.percent(modelData.percent)
                                horizontalAlignment: Text.AlignRight
                                color: Theme.Colors.foreground
                                font.pixelSize: 12
                            }
                        }
                        Meter {
                            width: parent.width
                            fraction: modelData.percent
                            fillColor: modelData.percent >= 0.9 ? "#fbbf24" : Theme.Colors.accent
                        }
                        Text {
                            text: root.bytes(modelData.used) + " used · " + root.bytes(modelData.free) + " available"
                            color: root.muted
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.Colors.activeWorkspace
            }
            Text {
                width: parent.width
                text: root.snapshot ? "Up " + root.uptime(root.snapshot.uptime) + "  ·  Load " + root.snapshot.load.map(value => value.toFixed(2)).join(" / ") : "Waiting for system data…"
                color: root.muted
                font.pixelSize: 10
            }
        }
    }

    Rectangle {
        x: parent.width - 8
        y: viewport.y + viewport.visibleArea.yPosition * viewport.height
        width: 3
        height: viewport.visibleArea.heightRatio * viewport.height
        radius: 2
        color: root.muted
        opacity: 0.5
        visible: viewport.contentHeight > viewport.height
    }
}
