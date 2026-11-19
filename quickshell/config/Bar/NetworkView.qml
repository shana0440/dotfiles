import QtQuick
import Quickshell
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    property bool active: false
    property int maximumHeight: 560
    signal closeRequested()

    readonly property var primary: devices.primary
    readonly property var primaryRates: primary ? sampler.networkRates.find(rate => rate.label === primary.device) ?? null : null
    readonly property var others: devices.devices.filter(device => device.connected && device !== primary)
    readonly property var unplugged: devices.devices.filter(device => device.type === "ethernet" && !device.connected)
    readonly property var activeNetwork: wifi.current

    readonly property int historyLength: 60
    property var history: []
    property string historyDevice: ""

    readonly property int rowHeight: 40

    implicitWidth: 480
    implicitHeight: content.implicitHeight + 40
    clip: true

    onActiveChanged: history = []

    function rate(value) {
        if (value === null || value === undefined)
            return "—"
        const units = ["B/s", "KiB/s", "MiB/s", "GiB/s"]
        let unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            unit++
        }
        return value.toFixed(unit ? 1 : 0) + " " + units[unit]
    }

    function linkSpeed(megabits) {
        return megabits >= 1000 ? (megabits / 1000) + " Gb/s" : megabits + " Mb/s"
    }

    function detailOf(device) {
        if (device.type === "wifi")
            return device.connection + (activeNetwork ? " · " + activeNetwork.strength + "%" : "")
        if (device.type === "ethernet")
            return device.device + (device.speed > 0 ? " · " + linkSpeed(device.speed) : "")
        return device.kind === "VPN" ? device.device : ""
    }

    function ratesOf(device) {
        return sampler.networkRates.find(rate => rate.label === device.device) ?? null
    }

    WifiController {
        id: wifi
        active: root.active
    }

    SystemSampler {
        id: sampler
        active: root.active
    }

    NetworkDevices {
        id: devices
        active: root.active
    }

    Connections {
        target: sampler
        function onNetworkRatesChanged() {
            const rates = root.primaryRates
            if (!root.primary || !rates || rates.incoming === null)
                return
            const next = root.historyDevice === root.primary.device ? root.history.slice() : []
            next.push({ down: rates.incoming, up: rates.outgoing ?? 0 })
            root.historyDevice = root.primary.device
            root.history = next.slice(-root.historyLength)
        }
    }

    component LinkLight: Rectangle {
        property bool lit: false
        width: 8
        height: 8
        radius: 4
        color: lit ? Theme.Colors.success : Theme.Colors.track
    }

    component SectionLabel: Text {
        color: Theme.Colors.muted
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        font.pixelSize: 12
    }

    component Rate: Item {
        id: rateItem
        property bool upload: false
        property var value: null
        property int size: 12
        readonly property color tone: upload ? Theme.Colors.muted : Theme.Colors.foreground

        height: rateValue.implicitHeight

        Text {
            id: rateValue
            anchors.right: parent.right
            text: root.rate(rateItem.value)
            color: rateItem.tone
            font.family: Theme.Fonts.mono
            font.pixelSize: rateItem.size
        }
        Text {
            anchors.right: rateValue.left
            anchors.rightMargin: 4
            anchors.verticalCenter: rateValue.verticalCenter
            text: rateItem.upload ? "↑" : "↓"
            color: Theme.Colors.muted
            font.family: Theme.Fonts.family
            font.pixelSize: rateItem.size
        }
    }

    Column {
        id: content
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 16

        Item {
            id: header
            width: parent.width
            height: 32

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Network"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    text: !devices.loaded ? "Checking"
                        : !root.primary ? "Offline"
                        : "Online via " + root.primary.kind
                            + (root.primary.type !== "wifi" && root.activeNetwork ? ", Wi-Fi also connected" : "")
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Components.IconButton {
                    width: 32
                    height: 32
                    iconSize: 16
                    icon: "settings"
                    tooltip: "Advanced settings"
                    onClicked: {
                        root.closeRequested()
                        Quickshell.execDetached(["kitty", "--class", "wifi-settings", "-e", "nmtui"])
                    }
                }
            }
        }

        Rectangle {
            id: hero
            width: parent.width
            height: heroContent.implicitHeight + 32
            radius: 12
            color: Theme.Colors.surface

            Column {
                id: heroContent
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 12

                Item {
                    width: parent.width
                    height: 40

                    LinkLight {
                        y: 6
                        lit: root.primary !== null
                    }
                    Column {
                        x: 16
                        width: parent.width - x - heroRates.width - 12
                        spacing: 4

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                id: heroKind
                                text: root.primary ? root.primary.kind : devices.loaded ? "Offline" : "Checking"
                                color: Theme.Colors.foreground
                                font.family: Theme.Fonts.family
                                font.weight: Theme.Fonts.weight
                                font.pixelSize: 15
                            }
                            Text {
                                anchors.baseline: heroKind.baseline
                                width: parent.width - heroKind.width - parent.spacing
                                text: root.primary ? root.detailOf(root.primary) : devices.loaded ? "No connection carries the default route" : ""
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Theme.Colors.muted
                                font.family: Theme.Fonts.family
                                font.weight: Theme.Fonts.weight
                                font.pixelSize: 12
                            }
                        }
                        Text {
                            visible: root.primary !== null && root.primary.address.length > 0
                            text: root.primary ? root.primary.address + (root.primary.gateway ? "  via " + root.primary.gateway : "") : ""
                            color: Theme.Colors.muted
                            font.family: Theme.Fonts.mono
                            font.pixelSize: 12
                        }
                    }
                    Column {
                        id: heroRates
                        anchors.right: parent.right
                        width: 112
                        spacing: 4
                        visible: root.primary !== null

                        Rate {
                            width: parent.width
                            value: root.primaryRates?.incoming
                            size: 13
                        }
                        Rate {
                            width: parent.width
                            upload: true
                            value: root.primaryRates?.outgoing
                            size: 13
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 64
                    visible: root.primary !== null

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.Colors.track
                    }

                    Canvas {
                        id: chart
                        anchors.fill: parent
                        readonly property var samples: root.history
                        readonly property real peak: Math.max(1024, ...samples.map(sample => Math.max(sample.down, sample.up)))
                        onSamplesChanged: requestPaint()
                        onWidthChanged: requestPaint()

                        onPaint: {
                            const context = getContext("2d")
                            context.reset()
                            if (samples.length < 2)
                                return
                            const step = width / (root.historyLength - 1)
                            const left = width - (samples.length - 1) * step
                            const yOf = value => height - 2 - (height - 6) * value / peak
                            const trace = key => {
                                context.beginPath()
                                samples.forEach((sample, index) => {
                                    const x = left + index * step
                                    if (index === 0)
                                        context.moveTo(x, yOf(sample[key]))
                                    else
                                        context.lineTo(x, yOf(sample[key]))
                                })
                            }

                            trace("down")
                            context.lineTo(width, height)
                            context.lineTo(left, height)
                            context.closePath()
                            context.fillStyle = Qt.rgba(0.98, 0.98, 0.98, 0.08)
                            context.fill()

                            context.lineJoin = "round"
                            context.lineWidth = 1.5
                            trace("down")
                            context.strokeStyle = Theme.Colors.foreground
                            context.stroke()

                            context.lineWidth = 1
                            trace("up")
                            context.strokeStyle = Theme.Colors.muted
                            context.stroke()
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: chart.samples.length > 1 ? "peak " + root.rate(chart.peak) : "collecting"
                        color: Theme.Colors.muted
                        font.family: Theme.Fonts.mono
                        font.pixelSize: 11
                    }
                }
            }
        }

        Column {
            id: links
            width: parent.width
            spacing: 8
            visible: root.others.length > 0 || root.unplugged.length > 0

            SectionLabel {
                leftPadding: 4
                text: "Connections"
            }

            Repeater {
                model: root.others.length

                Item {
                    id: link
                    required property int index
                    readonly property var device: root.others[index] ?? { kind: "", type: "", device: "", connection: "", address: "", speed: 0 }
                    readonly property var rates: root.ratesOf(device)

                    width: links.width
                    height: root.rowHeight

                    LinkLight {
                        x: 4
                        y: 6
                        lit: true
                    }
                    Column {
                        x: 20
                        width: parent.width - x - linkRates.width - 12
                        spacing: 4

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                id: linkKind
                                text: link.device.kind
                                color: Theme.Colors.foreground
                                font.family: Theme.Fonts.family
                                font.weight: Theme.Fonts.weight
                                font.pixelSize: 13
                            }
                            Text {
                                anchors.baseline: linkKind.baseline
                                width: parent.width - linkKind.width - parent.spacing
                                text: root.detailOf(link.device)
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Theme.Colors.muted
                                font.family: Theme.Fonts.family
                                font.weight: Theme.Fonts.weight
                                font.pixelSize: 12
                            }
                        }
                        Text {
                            text: link.device.address
                            color: Theme.Colors.muted
                            font.family: Theme.Fonts.mono
                            font.pixelSize: 12
                        }
                    }
                    Column {
                        id: linkRates
                        anchors.right: parent.right
                        width: 112
                        spacing: 4

                        Rate {
                            width: parent.width
                            value: link.rates?.incoming
                        }
                        Rate {
                            width: parent.width
                            upload: true
                            value: link.rates?.outgoing
                        }
                    }
                }
            }

            Item {
                width: links.width
                height: 16
                visible: root.unplugged.length > 0

                LinkLight {
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.unplugged.map(device => device.device).join(", ") + (root.unplugged.every(device => !device.carrier) ? " · cable unplugged" : " · disconnected")
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.mono
                    font.pixelSize: 12
                }
            }
        }
    }
}
