import QtQuick
import Quickshell
import "../Theme" as Theme
import "../Components" as Components

// The dashboard's network tab, read like a router's front panel: the connection
// carrying the default route with its recent traffic, the other live links, then
// Wi-Fi networks to join or leave.
Item {
    id: root

    property bool active: false
    property int maximumHeight: 560
    property string selectedSsid: ""
    signal closeRequested()

    readonly property var primary: devices.primary
    readonly property var primaryRates: primary ? sampler.networkRates.find(rate => rate.label === primary.device) ?? null : null
    // Live links besides the primary one, then wired ports with nothing plugged in.
    readonly property var others: devices.devices.filter(device => device.connected && device !== primary)
    readonly property var unplugged: devices.devices.filter(device => device.type === "ethernet" && !device.connected)
    readonly property var activeNetwork: {
        for (let i = 0; i < wifi.networks.count; i++) {
            const network = wifi.networks.get(i)
            if (network.active)
                return network
        }
        return null
    }

    // Two minutes of primary traffic at the sampler's 2-second step.
    readonly property int historyLength: 60
    property var history: []
    property string historyDevice: ""

    readonly property int rowHeight: 40
    readonly property int rowSpacing: 2

    // The Wi-Fi list is a page of its own, so status reads without it.
    property bool wifiOpen: false

    implicitWidth: 480
    implicitHeight: (wifiOpen ? wifiPage.implicitHeight : content.implicitHeight) + 40
    // The pages shift a little as they cross; keep that inside the tab.
    clip: true

    onActiveChanged: {
        clearSelection()
        history = []
        wifiOpen = false
    }

    function openWifi() {
        wifiOpen = true
        wifi.refresh()
    }

    function closeWifi() {
        clearSelection()
        wifiOpen = false
    }

    function clearSelection() {
        selectedSsid = ""
        password.text = ""
    }

    function selectNetwork(ssid, security) {
        selectedSsid = ssid
        password.text = ""
        wifi.message = ""
        if (!secured(security))
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

    function secured(security) {
        return security && security !== "--"
    }

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

    // What follows the kind: the Wi-Fi network, or the port and its speed.
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

    // A port light: lit while the link is up.
    component LinkLight: Rectangle {
        property bool lit: false
        width: 8
        height: 8
        radius: 4
        color: lit ? Theme.Colors.success : Theme.Colors.track
    }

    component SignalBars: Item {
        property int strength: 0
        property bool emphasized: false
        width: 16
        height: 14

        Repeater {
            model: 4

            Rectangle {
                required property int index
                x: index * 4
                y: parent.height - height
                width: 3
                height: 5 + index * 3
                radius: 1
                color: parent.strength > index * 25 ? (parent.emphasized ? Theme.Colors.foreground : Theme.Colors.muted) : Theme.Colors.track
            }
        }
    }

    component TextButton: Rectangle {
        id: button
        property string label: ""
        property bool primary: false
        signal clicked()

        implicitWidth: buttonText.implicitWidth + 24
        implicitHeight: 28
        radius: 8
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

    component SectionLabel: Text {
        color: Theme.Colors.muted
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        font.pixelSize: 12
    }

    // A rate right-aligned in mono; the arrow comes from the UI face, which has the glyph.
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

    // 0 shows status, 1 the Wi-Fi page; each fades and shifts toward where it lives.
    Components.Spring {
        id: pageSpring
        to: root.wifiOpen ? 1 : 0
        stiffness: Theme.Motion.stackStiffness
        damping: Theme.Motion.stackDamping
        precision: 0.002
    }

    Column {
        id: content
        x: 20 - 24 * pageSpring.value
        y: 20
        width: parent.width - 40
        spacing: 16
        opacity: 1 - pageSpring.value
        visible: opacity > 0
        enabled: !root.wifiOpen

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
                    enabled: !wifi.busy
                    onClicked: {
                        root.closeRequested()
                        Quickshell.execDetached(["kitty", "--class", "wifi-settings", "-e", "nmtui"])
                    }
                }
            }
        }

        // The connection carrying the default route, and its last two minutes.
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

                            // Download carries the weight: a line with a faint fill below it.
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

                    // The scale, top left, clear of the newest samples on the right.
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

        // Other live links, each with its address and traffic.
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
                // A count model keeps the rows across polls.
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

            // Empty ports collapse into one dim line.
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

        // The way into the Wi-Fi page.
        Rectangle {
            id: wifiEntry
            width: parent.width
            height: root.rowHeight
            radius: 8
            color: entryMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent
            Accessible.role: Accessible.Button
            Accessible.name: "Wi-Fi networks"

            SignalBars {
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                strength: root.activeNetwork ? root.activeNetwork.strength : 0
                emphasized: root.activeNetwork !== null
            }
            Text {
                x: 32
                anchors.verticalCenter: parent.verticalCenter
                text: "Wi-Fi networks"
                color: Theme.Colors.foreground
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 13
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wifi.networks.count > 0 ? wifi.networks.count + " nearby" : wifi.scanning ? "Scanning" : "None nearby"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }
                Components.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    action: "forward"
                    iconColor: Theme.Colors.muted
                }
            }
            MouseArea {
                id: entryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openWifi()
            }
        }
    }

    // The nested Wi-Fi page: networks to join or leave.
    Column {
        id: wifiPage
        x: 20 + 24 * (1 - pageSpring.value)
        y: 20
        width: parent.width - 40
        spacing: 12
        opacity: pageSpring.value
        visible: opacity > 0
        enabled: root.wifiOpen

        Item {
            id: wifiHeader
            width: parent.width
            height: 32

            Components.IconButton {
                id: back
                x: -6
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                iconSize: 18
                icon: "back"
                tooltip: "Back to network"
                onClicked: root.closeWifi()
            }
            Column {
                anchors.left: back.right
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Wi-Fi networks"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    text: wifi.scanning && wifi.networks.count === 0 ? "Scanning"
                        : (root.activeNetwork ? "Connected to " + root.activeNetwork.ssid : "Not connected")
                            + " \u00b7 " + wifi.networks.count + " nearby"
                    textFormat: Text.PlainText
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }
            }
            Components.IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                iconSize: 16
                icon: "reboot"
                tooltip: wifi.scanning ? "Scanning" : "Scan again"
                enabled: !wifi.scanning && !wifi.busy
                onClicked: wifi.refresh()
            }
        }

        Column {
            id: networksSection
            width: parent.width
            spacing: 8

            Text {
                id: message
                width: parent.width
                leftPadding: 4
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
                readonly property real room: root.maximumHeight - 40 - wifiHeader.height - wifiPage.spacing
                    - (message.visible ? message.height + networksSection.spacing : 0)
                    - (form.visible ? form.height + networksSection.spacing : 0)

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
                    readonly property bool hovered: rowHover.hovered

                    width: networkList.width
                    height: root.rowHeight
                    radius: 8
                    color: selected || hovered ? Theme.Colors.highlight : Theme.Colors.transparent

                    HoverHandler { id: rowHover }

                    SignalBars {
                        x: 4
                        anchors.verticalCenter: parent.verticalCenter
                        strength: row.strength
                        emphasized: row.active
                    }
                    Text {
                        x: 32
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - trailing.width - 16
                        text: row.ssid
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Colors.foreground
                        font.family: Theme.Fonts.family
                        font.weight: Theme.Fonts.weight
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: row.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!row.active)
                                root.selectNetwork(row.ssid, row.security)
                        }
                    }

                    // Status, and on the current network a Disconnect that asks twice:
                    // nothing moves under the pointer, and one stray click cannot drop Wi-Fi.
                    Row {
                        id: trailing
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !disconnect.armed
                            text: row.active ? "Connected" : root.secured(row.security) ? "Secured" : "Open"
                            color: row.active ? Theme.Colors.success : Theme.Colors.muted
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 12
                        }
                        TextButton {
                            id: disconnect
                            property bool armed: false
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.active
                            label: armed ? "Confirm disconnect" : "Disconnect"
                            primary: armed
                            onClicked: {
                                if (!armed) {
                                    armed = true
                                    disarm.restart()
                                    return
                                }
                                armed = false
                                root.clearSelection()
                                wifi.disconnect(row.device)
                            }

                            Timer {
                                id: disarm
                                interval: 4000
                                onTriggered: disconnect.armed = false
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: networkList.count === 0 && !message.visible
                    text: wifi.scanning ? "Scanning" : "No networks"
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
                    color: Theme.Colors.surface
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
                        Keys.onEscapePressed: root.closeWifi()
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24
                        visible: !password.text
                        text: "Password for " + root.selectedSsid + ", blank uses the saved one"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
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
                        label: wifi.connecting ? "Connecting" : "Connect"
                        enabled: !wifi.busy
                        onClicked: root.connectSelected()
                    }
                }
            }
        }
    }

    // Mouse side buttons, routed here by the dashboard from anywhere over the page:
    // Back returns to status, Forward goes into Wi-Fi.
    function navigateBack() {
        if (wifiOpen)
            closeWifi()
    }

    function navigateForward() {
        if (!wifiOpen)
            openWifi()
    }
}
