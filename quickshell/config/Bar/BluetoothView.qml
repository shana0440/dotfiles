import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

// The dashboard's Bluetooth tab: power and visibility, pairing prompts, your
// devices, then nearby ones to pair. Scans while the tab is open.
Item {
    id: root

    property bool active: false
    property int maximumHeight: 560
    signal closeRequested()

    readonly property var adapter: Services.Bluetooth.adapter
    readonly property bool powered: Services.Bluetooth.enabled
    readonly property var request: Services.Bluetooth.request
    readonly property bool needsValue: request !== null && (request.type === "pin" || request.type === "passkey")
    // Scan while the tab is open, unless the user stopped it.
    property bool scanRequested: true
    property string message: ""
    property string expandedAddress: ""
    // Devices to trust and connect once pairing succeeds.
    property var pairTargets: ({})

    readonly property var pairedDevices: Services.Bluetooth.devices
        .filter(device => device.paired)
        .sort((a, b) => Number(b.connected) - Number(a.connected) || a.name.localeCompare(b.name))
    // Unnamed devices are usually beacons and other non-pairable noise.
    readonly property var nearbyDevices: Services.Bluetooth.devices
        .filter(device => !device.paired && device.deviceName.length > 0)
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var connected: pairedDevices.filter(device => device.connected)

    implicitWidth: 480
    implicitHeight: Math.min(maximumHeight, content.implicitHeight + 40)

    onActiveChanged: {
        message = ""
        expandedAddress = ""
        scanRequested = true
        updateDiscovery()
    }
    onPoweredChanged: updateDiscovery()
    onScanRequestedChanged: updateDiscovery()
    onRequestChanged: {
        valueInput.text = ""
        if (needsValue)
            Qt.callLater(() => valueInput.forceActiveFocus())
    }

    function updateDiscovery() {
        Services.Bluetooth.setDiscovering(active && powered && scanRequested)
    }

    function statusText() {
        if (!Services.Bluetooth.available)
            return "No Bluetooth adapter"
        if (adapter?.state === BluetoothAdapterState.Blocked)
            return "Blocked by airplane mode"
        if (adapter?.state === BluetoothAdapterState.Enabling)
            return "Turning on"
        if (!powered)
            return "Off"
        if (connected.length === 1)
            return "Connected to " + connected[0].name
        if (connected.length > 1)
            return connected.length + " devices connected"
        return "On, nothing connected"
    }

    function stateText(device) {
        if (device.pairing)
            return "Pairing"
        switch (device.state) {
        case BluetoothDeviceState.Connecting: return "Connecting"
        case BluetoothDeviceState.Disconnecting: return "Disconnecting"
        case BluetoothDeviceState.Connected:
            return "Connected" + (device.batteryAvailable ? " \u00b7 " + Math.round(device.battery * 100) + "% battery" : "")
        }
        if (device.paired)
            return device.trusted ? "Paired \u00b7 trusted" : "Paired"
        return device.address
    }

    function pair(device) {
        message = "Pairing with " + device.name
        pairTargets[device.address] = true
        device.pair()
    }

    function pairingFinished(device) {
        if (!pairTargets[device.address])
            return
        delete pairTargets[device.address]
        if (device.paired) {
            message = "Paired with " + device.name
            device.trusted = true
            device.connect()
        } else {
            message = "Pairing with " + device.name + " failed. Make sure it is in pairing mode."
        }
    }

    function forget(device) {
        message = "Removed " + device.name
        expandedAddress = ""
        device.forget()
    }

    function cancelPrompt() {
        if (request?.type.startsWith("display-")) {
            const device = Services.Bluetooth.devices.find(device => device.dbusPath === request.device)
            device?.cancelPair()
        }
        Services.Bluetooth.respond(false)
    }

    function submitPrompt() {
        if (needsValue && valueInput.text.length === 0)
            return
        Services.Bluetooth.respond(true, valueInput.text)
        valueInput.text = ""
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
            : buttonMouse.containsMouse || activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
        border.width: primary ? 0 : 1
        border.color: Theme.Colors.ring
        opacity: enabled ? 1 : 0.4
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()

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

    component Switch: Rectangle {
        id: toggle
        property bool checked: false
        property string label: ""
        signal toggled()

        implicitWidth: 40
        implicitHeight: 22
        radius: height / 2
        color: checked ? Theme.Colors.foreground : Theme.Colors.track
        opacity: enabled ? 1 : 0.4
        activeFocusOnTab: true
        border.width: activeFocus ? 2 : 0
        border.color: Theme.Colors.muted
        Accessible.role: Accessible.CheckBox
        Accessible.name: label
        Accessible.checked: checked
        Keys.onReturnPressed: toggled()
        Keys.onSpacePressed: toggled()

        Rectangle {
            y: 3
            x: knob.value
            width: 16
            height: 16
            radius: 8
            color: toggle.checked ? Theme.Colors.background : Theme.Colors.foreground

            Components.Spring {
                id: knob
                to: toggle.checked ? toggle.width - 16 - 3 : 3
                stiffness: Theme.Motion.enterStiffness
                damping: Theme.Motion.enterDamping
            }
        }
        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
        Components.Tooltip {
            text: toggle.label
            shown: toggleMouse.containsMouse
        }
    }

    component SectionLabel: Text {
        leftPadding: 4
        color: Theme.Colors.muted
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        font.pixelSize: 12
    }

    component DeviceRow: Rectangle {
        id: row
        required property var modelData
        readonly property var device: modelData
        readonly property bool expanded: root.expandedAddress === device.address
        readonly property bool busy: device.pairing || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting

        width: parent.width
        height: heightSpring.value
        radius: 8
        color: expanded || rowMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent
        clip: true

        Components.Spring {
            id: heightSpring
            to: 48 + (row.expanded ? actions.height + 8 : 0)
            stiffness: row.expanded ? Theme.Motion.morphStiffness : Theme.Motion.closeStiffness
            damping: row.expanded ? Theme.Motion.morphDamping : Theme.Motion.closeDamping
        }

        Connections {
            target: row.device
            // Rows move between lists when pairing succeeds, so let BlueZ settle first.
            function onPairingChanged() {
                if (!row.device.pairing)
                    Qt.callLater(root.pairingFinished, row.device)
            }
            function onPairedChanged() {
                if (row.device.paired)
                    root.pairingFinished(row.device)
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.device.paired ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (row.device.paired)
                    root.expandedAddress = row.expanded ? "" : row.device.address
            }
        }

        Components.Icon {
            x: 8
            y: 15
            width: 18
            height: 18
            action: row.device.connected ? "bluetoothConnected" : "bluetooth"
            iconColor: row.device.connected ? Theme.Colors.foreground : Theme.Colors.muted
        }

        Column {
            x: 36
            y: 7
            width: parent.width - x - primaryButton.width - 20
            spacing: 2

            Text {
                width: parent.width
                text: row.device.name
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.Colors.foreground
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 13
            }
            Text {
                width: parent.width
                text: root.stateText(row.device)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: row.device.connected ? Theme.Colors.success : Theme.Colors.muted
                font.family: row.device.paired || row.device.pairing ? Theme.Fonts.family : Theme.Fonts.mono
                font.weight: Theme.Fonts.weight
                font.pixelSize: 11
            }
        }

        TextButton {
            id: primaryButton
            anchors.right: parent.right
            anchors.rightMargin: 10
            y: 10
            enabled: !row.busy || row.device.pairing
            label: row.device.pairing ? "Cancel"
                : !row.device.paired ? "Pair"
                : row.device.connected ? "Disconnect" : "Connect"
            onClicked: {
                if (row.device.pairing)
                    row.device.cancelPair()
                else if (!row.device.paired)
                    root.pair(row.device)
                else if (row.device.connected)
                    row.device.disconnect()
                else
                    row.device.connect()
            }
        }

        Row {
            id: actions
            x: 36
            y: 48
            spacing: 8
            visible: row.expanded

            TextButton {
                label: row.device.trusted ? "Untrust" : "Trust"
                onClicked: row.device.trusted = !row.device.trusted
            }
            TextButton {
                label: row.device.blocked ? "Unblock" : "Block"
                onClicked: row.device.blocked = !row.device.blocked
            }
            TextButton {
                label: "Forget"
                onClicked: root.forget(row.device)
            }
        }
    }

    Flickable {
        x: 20
        y: 20
        width: parent.width - 40
        height: parent.height - 40
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            width: parent.width
            spacing: 16

            Item {
                width: parent.width
                height: 32

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - controls.width - 12
                    spacing: 2

                    Text {
                        text: "Bluetooth"
                        color: Theme.Colors.foreground
                        font.family: Theme.Fonts.family
                        font.pixelSize: 16
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: root.statusText()
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Colors.muted
                        font.family: Theme.Fonts.family
                        font.weight: Theme.Fonts.weight
                        font.pixelSize: 11
                    }
                }
                Row {
                    id: controls
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        label: root.powered ? "Turn Bluetooth off" : "Turn Bluetooth on"
                        checked: root.powered
                        enabled: Services.Bluetooth.available && root.adapter?.state !== BluetoothAdapterState.Blocked
                        onToggled: Services.Bluetooth.setEnabled(!root.powered)
                    }
                    Components.IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        iconSize: 16
                        icon: "settings"
                        tooltip: "Advanced settings"
                        onClicked: {
                            root.closeRequested()
                            Quickshell.execDetached(["kitty", "--class", "bluetooth-settings", "-e", "bluetoothctl"])
                        }
                    }
                }
            }

            // Visibility to other devices, and what just happened.
            Column {
                width: parent.width
                spacing: 8
                visible: root.powered

                Item {
                    width: parent.width
                    height: 22

                    Text {
                        x: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - visibility.width - 12
                        text: (root.adapter?.discoverable ? "Visible as " : "Hidden, named ") + (root.adapter?.name ?? "")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: root.adapter?.discoverable ? Theme.Colors.foreground : Theme.Colors.muted
                        font.family: Theme.Fonts.family
                        font.weight: Theme.Fonts.weight
                        font.pixelSize: 12
                    }
                    Switch {
                        id: visibility
                        anchors.right: parent.right
                        anchors.rightMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        label: root.adapter?.discoverable ? "Hide from other devices" : "Make visible to other devices"
                        checked: root.adapter?.discoverable ?? false
                        onToggled: root.adapter.discoverable = !root.adapter.discoverable
                    }
                }
                Text {
                    width: parent.width
                    leftPadding: 4
                    text: !Services.Bluetooth.agentRunning ? "Pairing agent is not running, so PIN pairing may fail" : root.message
                    textFormat: Text.PlainText
                    visible: text.length > 0
                    wrapMode: Text.Wrap
                    color: !Services.Bluetooth.agentRunning ? Theme.Colors.warning : Theme.Colors.foreground
                    opacity: Services.Bluetooth.agentRunning ? 0.7 : 1
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }
            }

            // A pairing prompt from the BlueZ agent.
            Rectangle {
                width: parent.width
                height: prompt.implicitHeight + 32
                radius: 12
                visible: root.request !== null
                color: Theme.Colors.surface
                border.width: 1
                border.color: Theme.Colors.info

                Column {
                    id: prompt
                    x: 16
                    y: 16
                    width: parent.width - 32
                    spacing: 12

                    Text {
                        width: parent.width
                        text: {
                            const request = root.request
                            if (!request)
                                return ""
                            const name = request.name
                            switch (request.type) {
                            case "pin": return "Enter the PIN code for " + name
                            case "passkey": return "Enter the passkey shown on " + name
                            case "confirm": return "Confirm that " + name + " shows this passkey"
                            case "authorize": return name + " wants to pair with this computer"
                            case "service": return name + " wants to use a Bluetooth service"
                            case "display-pin":
                            case "display-passkey": return "Type this code on " + name + ", then press Enter on it"
                            }
                            return name
                        }
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: Theme.Colors.foreground
                        font.family: Theme.Fonts.family
                        font.weight: Theme.Fonts.weight
                        font.pixelSize: 13
                    }
                    Text {
                        width: parent.width
                        visible: text.length > 0
                        text: root.request?.passkey ?? ""
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.Colors.foreground
                        font.family: Theme.Fonts.mono
                        font.pixelSize: 28
                        font.letterSpacing: 4
                    }
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 8
                        visible: root.needsValue
                        color: Theme.Colors.background
                        border.width: 1
                        border.color: valueInput.activeFocus ? Theme.Colors.muted : Theme.Colors.ring

                        TextInput {
                            id: valueInput
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.Colors.foreground
                            font.family: Theme.Fonts.mono
                            font.pixelSize: 13
                            selectByMouse: true
                            clip: true
                            validator: RegularExpressionValidator {
                                regularExpression: root.request?.type === "passkey" ? /[0-9]{0,6}/ : /.{0,16}/
                            }
                            onAccepted: root.submitPrompt()
                            Keys.onEscapePressed: root.cancelPrompt()
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !valueInput.text
                            text: root.request?.type === "passkey" ? "6-digit passkey" : "PIN code, often 0000 or 1234"
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
                            label: root.request?.type.startsWith("display-") ? "Cancel pairing"
                                : root.request?.type === "confirm" ? "Doesn't match" : "Cancel"
                            onClicked: root.cancelPrompt()
                        }
                        TextButton {
                            primary: true
                            visible: !(root.request?.type.startsWith("display-") ?? false)
                            enabled: !root.needsValue || valueInput.text.length > 0
                            label: root.request?.type === "confirm" ? "Matches"
                                : root.request?.type === "authorize" || root.request?.type === "service" ? "Allow" : "Pair"
                            onClicked: root.submitPrompt()
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.powered && root.pairedDevices.length > 0

                SectionLabel {
                    text: "My devices"
                }
                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.pairedDevices
                        delegate: DeviceRow {}
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.powered

                Item {
                    width: parent.width
                    height: 28

                    SectionLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Nearby devices"
                    }
                    TextButton {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        label: Services.Bluetooth.discovering ? "Stop scan" : "Scan"
                        // One request per click: a changed scanRequested already updates discovery.
                        onClicked: {
                            const wanted = !Services.Bluetooth.discovering
                            if (root.scanRequested !== wanted)
                                root.scanRequested = wanted
                            else
                                root.updateDiscovery()
                        }
                    }
                }
                Text {
                    width: parent.width
                    leftPadding: 4
                    visible: root.nearbyDevices.length === 0
                    text: Services.Bluetooth.discovering ? "Looking for devices in pairing mode" : "Scan to find devices in pairing mode"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }
                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.nearbyDevices
                        delegate: DeviceRow {}
                    }
                }
            }
        }
    }
}
