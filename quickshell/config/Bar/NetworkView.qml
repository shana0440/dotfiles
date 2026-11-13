import QtQuick
import Quickshell
import "../Theme" as Theme
import "../Components" as Components

// The dashboard's network tab: Wi-Fi networks to join or leave, then live traffic
// for each interface.
Item {
    id: root

    property bool active: false
    property int maximumHeight: 560
    property string selectedSsid: ""
    signal closeRequested()

    readonly property int rowHeight: 48
    readonly property int rowSpacing: 4
    readonly property var connectedNetwork: {
        for (let i = 0; i < wifi.networks.count; i++) {
            const network = wifi.networks.get(i)
            if (network.active)
                return network
        }
        return null
    }

    implicitWidth: 480
    implicitHeight: content.implicitHeight + 40

    onActiveChanged: clearSelection()

    function clearSelection() {
        selectedSsid = ""
        password.text = ""
    }

    function selectNetwork(ssid, security) {
        selectedSsid = ssid
        password.text = ""
        wifi.message = ""
        if (!security || security === "--")
            connectSelected()
        else
            Qt.callLater(() => password.forceActiveFocus())
    }

    function connectSelected() {
        if (!selectedSsid || wifi.busy)
            return
        wifi.connect(selectedSsid, password.text)
        password.text = ""
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

    WifiController {
        id: wifi
        active: root.active
        onConnectionChanged: root.clearSelection()
    }

    SystemSampler {
        id: sampler
        active: root.active
    }

    NetworkDevices {
        id: devices
        active: root.active
    }

    readonly property bool wiredConnected: devices.wired.some(device => device.connected)

    function linkSpeed(megabits) {
        return megabits >= 1000 ? (megabits / 1000) + " Gb/s" : megabits + " Mb/s"
    }

    function wiredStatus(device) {
        if (device.connected)
            return "Connected" + (device.speed > 0 ? " · " + linkSpeed(device.speed) : "")
        if (!device.carrier)
            return "Cable unplugged"
        return device.state.charAt(0).toUpperCase() + device.state.slice(1)
    }

    component TextButton: Rectangle {
        id: button
        property string label: ""
        property bool primary: false
        signal clicked()

        implicitWidth: buttonText.implicitWidth + 24
        implicitHeight: 30
        radius: 15
        color: primary ? (buttonMouse.containsMouse ? Qt.tint(Theme.Colors.foreground, "#2e0c0c0d") : Theme.Colors.foreground)
            : buttonMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent
        border.width: primary ? 0 : 1
        border.color: Theme.Colors.ring
        opacity: enabled ? 1 : 0.4
        Accessible.role: Accessible.Button
        Accessible.name: label

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            color: button.primary ? Theme.Colors.background : Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 12
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
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
                    readonly property var links: (root.wiredConnected ? ["Ethernet"] : [])
                        .concat(root.connectedNetwork ? ["Wi-Fi " + root.connectedNetwork.ssid] : [])
                    text: links.length > 0 ? "Connected via " + links.join(" and ")
                        : !devices.loaded || (wifi.scanning && wifi.networks.count === 0) ? "Checking…" : "Not connected"
                    textFormat: Text.PlainText
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
                    radius: 16
                    iconSize: 16
                    icon: "reboot"
                    tooltip: wifi.scanning ? "Scanning…" : "Scan for networks"
                    enabled: !wifi.scanning && !wifi.busy
                    onClicked: wifi.refresh()
                }
                Components.IconButton {
                    width: 32
                    height: 32
                    radius: 16
                    iconSize: 16
                    icon: "settings"
                    tooltip: "Advanced settings"
                    enabled: !wifi.busy
                    onClicked: {
                        root.closeRequested()
                        Quickshell.execDetached(["kitty", "--class", "wifi-settings", "-e", "nmtui"])
                    }
                }
            }
        }

        Rectangle {
            id: ethernetCard
            width: parent.width
            height: wired.implicitHeight + 24
            radius: 12
            color: Theme.Colors.surface
            visible: devices.wired.length > 0

            Column {
                id: wired
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 4

                Text {
                    leftPadding: 2
                    bottomPadding: 4
                    text: "Ethernet"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }

                Repeater {
                    // A count model keeps the rows across polls.
                    model: devices.wired.length

                    Rectangle {
                        id: port
                        required property int index
                        readonly property var device: devices.wired[index] ?? { device: "", connection: "", state: "", connected: false, carrier: false, speed: 0, address: "", gateway: "", dns: "" }

                        width: wired.width
                        height: portText.implicitHeight + 20
                        radius: 8
                        color: device.connected ? Theme.Colors.highlight : Theme.Colors.transparent

                        Components.Icon {
                            x: 10
                            y: 12
                            width: 18
                            height: 18
                            action: "ethernet"
                            iconColor: port.device.connected ? Theme.Colors.foreground : Theme.Colors.muted
                        }

                        Column {
                            id: portText
                            x: 40
                            y: 10
                            width: parent.width - x - address.width - 22
                            spacing: 2

                            Row {
                                width: parent.width
                                spacing: 6

                                Text {
                                    id: portName
                                    text: port.device.connection || port.device.device
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, parent.width - deviceName.implicitWidth - parent.spacing)
                                    color: Theme.Colors.foreground
                                    font.family: Theme.Fonts.family
                                    font.weight: Theme.Fonts.weight
                                    font.pixelSize: 13
                                }
                                Text {
                                    id: deviceName
                                    anchors.baseline: portName.baseline
                                    visible: port.device.connection.length > 0
                                    text: port.device.device
                                    textFormat: Text.PlainText
                                    color: Theme.Colors.muted
                                    font.family: Theme.Fonts.family
                                    font.weight: Theme.Fonts.weight
                                    font.pixelSize: 11
                                }
                            }
                            Text {
                                text: root.wiredStatus(port.device)
                                color: port.device.connected ? Theme.Colors.success : Theme.Colors.muted
                                font.family: Theme.Fonts.family
                                font.weight: Theme.Fonts.weight
                                font.pixelSize: 11
                            }
                            Text {
                                width: parent.width
                                visible: port.device.connected && (port.device.gateway || port.device.dns)
                                text: [port.device.gateway ? "Gateway " + port.device.gateway : "",
                                    port.device.dns ? "DNS " + port.device.dns : ""].filter(part => part).join(" · ")
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Theme.Colors.muted
                                font.family: Theme.Fonts.family
                                font.weight: Theme.Fonts.weight
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            id: address
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            y: 12
                            visible: port.device.address.length > 0
                            text: port.device.address.replace(/\/\d+$/, "")
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

        Rectangle {
            id: wifiCard
            width: parent.width
            height: wifiContent.implicitHeight + 24
            radius: 12
            color: Theme.Colors.surface

            Column {
                id: wifiContent
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 8

                Text {
                    id: wifiTitle
                    leftPadding: 2
                    text: "Wi-Fi"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }

                Text {
                    id: message
                    width: parent.width
                    leftPadding: 2
                    text: wifi.message
                    textFormat: Text.PlainText
                    visible: text.length > 0
                    wrapMode: Text.Wrap
                    color: Theme.Colors.foreground
                    opacity: 0.7
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }

                ListView {
                    id: networkList
                    // Whatever the page cap leaves after everything else, at least two rows.
                    readonly property real room: root.maximumHeight - 40 - header.height - content.spacing * 2
                        - (ethernetCard.visible ? ethernetCard.height + content.spacing : 0)
                        - activityCard.height - 24 - wifiTitle.height - wifiContent.spacing
                        - (message.visible ? message.height + wifiContent.spacing : 0)
                        - (form.visible ? form.height + wifiContent.spacing : 0)

                    width: parent.width
                    height: Math.max(root.rowHeight * 2 + root.rowSpacing, Math.min(contentHeight, room))
                    clip: true
                    spacing: root.rowSpacing
                    boundsBehavior: Flickable.StopAtBounds
                    model: wifi.networks
                    enabled: !wifi.busy

                    delegate: Rectangle {
                        id: row
                        required property string ssid
                        required property bool active
                        required property int strength
                        required property string security
                        required property string device
                        readonly property bool selected: root.selectedSsid === ssid
                        readonly property string address: active ? (devices.wirelessDevice(device)?.address ?? "").replace(/\/\d+$/, "") : ""

                        width: networkList.width
                        height: root.rowHeight
                        radius: 8
                        color: active || selected || rowMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent

                        Components.Icon {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            action: row.strength >= 67 ? "wifi" : row.strength >= 34 ? "wifiHigh" : "wifiLow"
                            iconColor: row.active ? Theme.Colors.foreground : Theme.Colors.muted
                        }

                        Column {
                            x: 40
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - (row.active ? disconnectButton.width + 20 : 56)
                            spacing: 2

                            Text {
                                width: parent.width
                                text: row.ssid
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Theme.Colors.foreground
                                font.family: Theme.Fonts.family
                                font.weight: Theme.Fonts.weight
                                font.pixelSize: 13
                            }
                            Text {
                                width: parent.width
                                text: row.active ? "Connected" + (row.address ? " · " + row.address : "")
                                    : (!row.security || row.security === "--" ? "Open" : row.security)
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: row.active ? Theme.Colors.success : Theme.Colors.muted
                                font.family: Theme.Fonts.family
                                font.weight: Theme.Fonts.weight
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !row.active
                            text: row.strength + "%"
                            color: Theme.Colors.muted
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 12
                            font.features: ({ "tnum": 1 })
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: row.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (!row.active)
                                    root.selectNetwork(row.ssid, row.security)
                            }
                        }

                        TextButton {
                            id: disconnectButton
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.active
                            label: "Disconnect"
                            onClicked: {
                                root.clearSelection()
                                wifi.disconnect(row.device)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: networkList.count === 0 && !message.visible
                        text: wifi.scanning ? "Scanning…" : "No networks"
                        color: Theme.Colors.muted
                        font.family: Theme.Fonts.family
                        font.weight: Theme.Fonts.weight
                        font.pixelSize: 12
                    }
                }

                // Joining a secured network: its password, or blank for saved credentials.
                Column {
                    id: form
                    width: parent.width
                    spacing: 8
                    visible: root.selectedSsid.length > 0

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 8
                        color: Theme.Colors.background
                        border.width: 1
                        border.color: password.activeFocus ? Theme.Colors.muted : Theme.Colors.ring

                        TextInput {
                            id: password
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            enabled: !wifi.busy
                            color: Theme.Colors.foreground
                            font.family: Theme.Fonts.family
                            font.pixelSize: 13
                            selectByMouse: true
                            clip: true
                            onAccepted: root.connectSelected()
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !password.text
                            text: "Password for " + root.selectedSsid + " (blank uses saved)"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            width: parent.width - 24
                            color: Theme.Colors.muted
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 12
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        TextButton {
                            label: "Cancel"
                            enabled: !wifi.busy
                            onClicked: root.clearSelection()
                        }
                        TextButton {
                            primary: true
                            label: wifi.connecting ? "Connecting…" : "Connect"
                            enabled: !wifi.busy
                            onClicked: root.connectSelected()
                        }
                    }
                }
            }
        }

        Rectangle {
            id: activityCard
            width: parent.width
            height: activity.implicitHeight + 24
            radius: 12
            color: Theme.Colors.surface

            Column {
                id: activity
                x: 14
                y: 12
                width: parent.width - 28
                spacing: 10

                Text {
                    text: "Activity"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }

                Repeater {
                    // A count model keeps the rows across samples.
                    model: sampler.networkRates.length

                    Item {
                        id: link
                        required property int index
                        readonly property var rates: sampler.networkRates[index] ?? { label: "", incoming: null, outgoing: null }

                        width: activity.width
                        height: linkName.implicitHeight

                        Text {
                            id: linkName
                            width: parent.width - download.width - upload.width
                            text: link.rates.label
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.Colors.foreground
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 12
                        }
                        Text {
                            id: download
                            x: linkName.width
                            width: 130
                            text: "↓ " + root.rate(link.rates.incoming)
                            horizontalAlignment: Text.AlignRight
                            color: Theme.Colors.foreground
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 12
                            font.features: ({ "tnum": 1 })
                        }
                        Text {
                            id: upload
                            anchors.right: parent.right
                            width: 130
                            text: "↑ " + root.rate(link.rates.outgoing)
                            horizontalAlignment: Text.AlignRight
                            color: Theme.Colors.foreground
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 12
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }

                Text {
                    visible: sampler.networkRates.length === 0
                    text: sampler.snapshot ? "No active network interfaces" : "Waiting for sample"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }
            }
        }
    }
}
