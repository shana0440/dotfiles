import QtQuick
import "../Theme" as Theme
import "../Components" as Components

// The dashboard's system tab: CPU and memory, then usage and VRAM for each GPU.
Item {
    id: root

    property bool active: false
    readonly property var snapshot: sampler.snapshot
    readonly property var memory: sampler.memory
    readonly property var cpuTemperature: sampler.temperature && sampler.temperature.cpu ? sampler.temperature : null

    implicitWidth: 480
    implicitHeight: content.implicitHeight + 40

    SystemSampler {
        id: sampler
        active: root.active
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

    function percent(value) {
        return Math.round(value * 100) + "%"
    }

    function uptime(seconds) {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor(seconds / 3600) % 24
        const minutes = Math.floor(seconds / 60) % 60
        return (days ? days + "d " : "") + hours + "h " + minutes + "m"
    }

    component Meter: Rectangle {
        id: meter
        // Below zero leaves the track empty and dimmed.
        property real fraction: -1
        property bool warning: false

        height: 4
        radius: 2
        color: Theme.Colors.track
        opacity: fraction >= 0 ? 1 : 0.5

        Rectangle {
            width: fill.value
            height: parent.height
            radius: parent.radius
            color: meter.warning ? Theme.Colors.warning : Theme.Colors.foreground

            Components.Spring {
                id: fill
                to: meter.width * Math.max(0, Math.min(1, meter.fraction))
                stiffness: Theme.Motion.stackStiffness
                damping: Theme.Motion.stackDamping
            }
        }
    }

    component Card: Rectangle {
        id: card
        property string label: ""
        property string value: "—"
        property string detail: ""
        // Below zero hides the meter.
        property real fraction: -1
        property bool warning: fraction >= 0.9

        width: (content.width - grid.columnSpacing) / 2
        height: 112
        radius: 12
        color: Theme.Colors.surface

        Column {
            x: 14
            y: 12
            width: parent.width - 28
            spacing: 6

            Text {
                text: card.label
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 12
            }
            Text {
                text: card.value
                color: card.warning ? Theme.Colors.warning : Theme.Colors.foreground
                font.family: Theme.Fonts.family
                font.weight: Font.DemiBold
                font.pixelSize: 28
                font.features: ({ "tnum": 1 })
            }
            Meter {
                width: parent.width
                fraction: card.fraction
                warning: card.warning
            }
            Text {
                width: parent.width
                text: card.detail
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 11
            }
        }
    }

    Column {
        id: content
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 16

        Item {
            width: parent.width
            height: 32

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "System"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    text: sampler.failed ? "Unable to read system metrics" : "Live · every 2 seconds"
                    color: sampler.failed ? Theme.Colors.warning : Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.snapshot !== null
                // Load averages over 1, 5 and 15 minutes.
                text: root.snapshot ? "Up " + root.uptime(root.snapshot.uptime)
                    + " · load " + root.snapshot.load.map(value => value.toFixed(2)).join(" ") : ""
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 12
            }
        }

        Grid {
            id: grid
            columns: 2
            columnSpacing: 12
            rowSpacing: 12

            Card {
                label: "CPU"
                value: sampler.cpuUsage !== null ? root.percent(sampler.cpuUsage) : "—"
                fraction: sampler.cpuUsage !== null ? sampler.cpuUsage : -1
                detail: !root.snapshot ? "Waiting for sample"
                    : root.snapshot.cores + " cores" + (root.cpuTemperature ? " · " + Math.round(root.cpuTemperature.celsius) + "°C" : "")
                warning: fraction >= 0.9 || (root.cpuTemperature !== null && root.cpuTemperature.celsius >= 85)
            }
            Card {
                label: "Memory"
                value: root.memory ? root.percent(root.memory.used / root.memory.total) : "—"
                fraction: root.memory ? root.memory.used / root.memory.total : -1
                detail: !root.memory ? "Waiting for sample"
                    : root.bytes(root.memory.used) + " / " + root.bytes(root.memory.total)
                        + (root.memory.swapTotal ? " · swap " + root.bytes(root.memory.swapUsed) : " · no swap")
            }

            // One row per GPU: usage on the left, VRAM on the right.
            Repeater {
                // A count model keeps the cards (and their meter springs) across samples.
                model: sampler.gpus.length * 2

                Card {
                    required property int index
                    readonly property bool isVram: index % 2 === 1
                    readonly property var gpu: sampler.gpus[Math.floor(index / 2)] ?? {}
                    readonly property bool hasVram: gpu.memoryUsed != null && gpu.memoryTotal > 0
                    readonly property bool hot: gpu.temperature != null && gpu.temperature >= 85

                    label: isVram ? "VRAM" : "GPU"
                    value: isVram ? (hasVram ? root.percent(gpu.memoryUsed / gpu.memoryTotal) : "—")
                        : gpu.usage != null ? root.percent(gpu.usage) : "—"
                    fraction: isVram ? (hasVram ? gpu.memoryUsed / gpu.memoryTotal : -1)
                        : gpu.usage != null ? gpu.usage : -1
                    detail: isVram
                        ? (hasVram ? root.bytes(gpu.memoryUsed) + " / " + root.bytes(gpu.memoryTotal) : "Dedicated VRAM unavailable")
                        : gpu.name + (gpu.temperature != null ? " · " + Math.round(gpu.temperature) + "°C" : "")
                    warning: fraction >= 0.9 || (!isVram && hot)
                }
            }

            // Keep the GPU row in place until telemetry arrives or turns out missing.
            Card {
                visible: sampler.gpus.length === 0
                label: "GPU"
                detail: root.snapshot ? "No supported GPU telemetry" : "Waiting for sample"
            }
            Card {
                visible: sampler.gpus.length === 0
                label: "VRAM"
                detail: root.snapshot ? "No supported GPU telemetry" : "Waiting for sample"
            }
        }

        Rectangle {
            width: parent.width
            height: storage.implicitHeight + 24
            radius: 12
            color: Theme.Colors.surface

            Column {
                id: storage
                x: 14
                y: 12
                width: parent.width - 28
                spacing: 12

                Text {
                    text: "Storage"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }

                Repeater {
                    // A count model keeps the rows (and their meter springs) across samples.
                    model: root.snapshot ? root.snapshot.storage.length : 0

                    Column {
                        id: volume
                        required property int index
                        readonly property var disk: root.snapshot?.storage[index] ?? { label: "", path: "", used: 0, free: 0, total: 0, percent: 0 }
                        readonly property bool full: disk.percent >= 0.9

                        width: storage.width
                        spacing: 6

                        Item {
                            width: parent.width
                            height: name.implicitHeight

                            Row {
                                width: parent.width - percentText.width - 8
                                spacing: 6

                                Text {
                                    id: name
                                    text: volume.disk.label
                                    color: Theme.Colors.foreground
                                    font.family: Theme.Fonts.family
                                    font.weight: Theme.Fonts.weight
                                    font.pixelSize: 14
                                }
                                Text {
                                    anchors.baseline: name.baseline
                                    width: parent.width - name.width - parent.spacing
                                    text: volume.disk.path
                                    textFormat: Text.PlainText
                                    elide: Text.ElideMiddle
                                    color: Theme.Colors.muted
                                    font.family: Theme.Fonts.family
                                    font.weight: Theme.Fonts.weight
                                    font.pixelSize: 12
                                }
                            }
                            Text {
                                id: percentText
                                // Same size as the label, so a shared top aligns their baselines.
                                anchors.right: parent.right
                                anchors.top: parent.top
                                text: root.percent(volume.disk.percent)
                                color: volume.full ? Theme.Colors.warning : Theme.Colors.foreground
                                font.family: Theme.Fonts.family
                                font.weight: Font.DemiBold
                                font.pixelSize: 14
                                font.features: ({ "tnum": 1 })
                            }
                        }
                        Meter {
                            width: parent.width
                            fraction: volume.disk.percent
                            warning: volume.full
                        }
                        Text {
                            text: root.bytes(volume.disk.used) + " used · " + root.bytes(volume.disk.free) + " free"
                            color: Theme.Colors.muted
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 11
                        }
                    }
                }

                Text {
                    visible: !root.snapshot || root.snapshot.storage.length === 0
                    text: root.snapshot ? "No mounted volumes" : "Waiting for sample"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.Colors.track
                    visible: sampler.diskRates.length > 0
                }

                // Activity is per physical disk, which need not map onto the volumes above.
                Repeater {
                    model: sampler.diskRates.length

                    Item {
                        id: activity
                        required property int index
                        readonly property var disk: sampler.diskRates[index] ?? { label: "", incoming: null, outgoing: null }

                        width: storage.width
                        height: diskName.implicitHeight

                        Text {
                            id: diskName
                            width: parent.width - readRate.width - writeRate.width
                            text: activity.disk.label
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.Colors.muted
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 12
                        }
                        Text {
                            id: readRate
                            x: diskName.width
                            width: 130
                            text: "Read  " + root.rate(activity.disk.incoming)
                            horizontalAlignment: Text.AlignRight
                            color: Theme.Colors.foreground
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 12
                            font.features: ({ "tnum": 1 })
                        }
                        Text {
                            id: writeRate
                            anchors.right: parent.right
                            width: 130
                            text: "Write  " + root.rate(activity.disk.outgoing)
                            horizontalAlignment: Text.AlignRight
                            color: Theme.Colors.foreground
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 12
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
            }
        }
    }
}
