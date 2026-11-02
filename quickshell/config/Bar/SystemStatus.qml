import QtQuick
import Quickshell.Io
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    property bool active: false
    property var snapshot: null
    property var previousCpu: null
    property var cpuUsage: null
    property bool failed: false
    signal closeRequested()

    implicitWidth: 380
    implicitHeight: content.implicitHeight + 32
    readonly property var memory: snapshot ? snapshot.memory : null
    readonly property var temperature: snapshot ? snapshot.temperature : null
    readonly property color muted: "#9c9ca8"

    onActiveChanged: {
        if (active) {
            previousCpu = null
            cpuUsage = null
            snapshot = null
            failed = false
        }
    }

    function bytes(value) {
        const gib = value / (1024 * 1024 * 1024)
        return gib >= 1 ? gib.toFixed(1) + " GiB" : (value / (1024 * 1024)).toFixed(0) + " MiB"
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
            if (!sample.running)
                sample.running = true
        }
    }

    Process {
        id: sample
        command: ["system-status-snapshot"]
        stdout: StdioCollector { id: output }
        onExited: code => {
            if (!root.active)
                return
            root.failed = code !== 0
            if (root.failed) {
                root.snapshot = null
                root.previousCpu = null
                root.cpuUsage = null
                return
            }
            try {
                const next = JSON.parse(output.text)
                const previous = root.previousCpu
                const delta = previous ? next.cpu.total - previous.total : 0
                root.cpuUsage = delta > 0 ? Math.max(0, Math.min(1, 1 - (next.cpu.idle - previous.idle) / delta)) : null
                root.previousCpu = next.cpu
                root.snapshot = next
            } catch (error) {
                root.failed = true
                root.snapshot = null
                root.previousCpu = null
                root.cpuUsage = null
            }
        }
        onRunningChanged: {
            if (!running && !output.text && root.active)
                root.failed = true
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
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
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
            Text { text: label; color: root.muted; font.pixelSize: 12 }
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

    // Consume clicks inside the expanded island rather than dismissing it.
    MouseArea { anchors.fill: parent }

    Column {
        id: content
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 14

        Row {
            width: parent.width
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
                Text { text: "System status"; color: Theme.Colors.foreground; font.pixelSize: 16; font.bold: true }
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
            Text { text: "STORAGE"; color: root.muted; font.pixelSize: 10; font.letterSpacing: 1.5 }
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

        Rectangle { width: parent.width; height: 1; color: Theme.Colors.activeWorkspace }
        Text {
            width: parent.width
            text: root.snapshot ? "Up " + root.uptime(root.snapshot.uptime) + "  ·  Load " + root.snapshot.load.map(value => value.toFixed(2)).join(" / ") : "Waiting for system data…"
            color: root.muted
            font.pixelSize: 10
        }
    }
}
