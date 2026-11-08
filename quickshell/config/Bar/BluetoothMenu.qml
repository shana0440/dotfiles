import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    property bool active: false
    property real maximumHeight: 720
    signal closeRequested()

    readonly property var adapter: Services.Bluetooth.adapter
    readonly property bool powered: Services.Bluetooth.enabled
    readonly property var request: Services.Bluetooth.request
    readonly property bool needsValue: request !== null && (request.type === "pin" || request.type === "passkey")
    // Scan while the menu is open, unless the user stopped it.
    property bool scanRequested: true
    property string message: ""
    property string expandedAddress: ""
    // Devices to trust and connect once pairing succeeds.
    property var pairTargets: ({})

    readonly property var pairedDevices: Services.Bluetooth.devices
        .filter(device => device.paired)
        .sort((a, b) => Number(b.connected) - Number(a.connected) || a.name.localeCompare(b.name))
    // Unnamed devices are usually beacons and other non-pairable noise.
    readonly property var availableDevices: Services.Bluetooth.devices
        .filter(device => !device.paired && device.deviceName.length > 0)
        .sort((a, b) => a.name.localeCompare(b.name))

    implicitWidth: 380
    implicitHeight: content.implicitHeight + 24
    focus: active

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

    function stateText(device) {
        if (device.pairing)
            return "Pairing…"
        switch (device.state) {
        case BluetoothDeviceState.Connecting: return "Connecting…"
        case BluetoothDeviceState.Disconnecting: return "Disconnecting…"
        case BluetoothDeviceState.Connected:
            return "Connected" + (device.batteryAvailable ? " · " + Math.round(device.battery * 100) + "% battery" : "")
        }
        if (device.paired)
            return device.trusted ? "Paired · trusted" : "Paired"
        return device.address
    }

    function pair(device) {
        message = "Pairing with " + device.name + "…"
        pairTargets[device.address] = true
        device.pair()
    }

    function pairingFinished(device) {
        if (!pairTargets[device.address])
            return
        delete pairTargets[device.address]
        if (device.paired) {
            message = "Paired with " + device.name + "."
            device.trusted = true
            device.connect()
        } else {
            message = "Pairing with " + device.name + " failed. Make sure it is in pairing mode."
        }
    }

    function forget(device) {
        message = "Removed " + device.name + "."
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

    component Button: Rectangle {
        property string label: ""
        property bool primary: false
        signal clicked()
        implicitWidth: buttonText.implicitWidth + 20
        implicitHeight: 30
        radius: 6
        color: primary ? Theme.Colors.accent
            : buttonMouse.containsMouse || activeFocus ? Theme.Colors.activeWorkspace : Theme.Colors.transparent
        opacity: enabled ? (primary && buttonMouse.containsMouse ? 0.85 : 1) : 0.4
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: parent.label
            color: parent.primary ? Theme.Colors.background : Theme.Colors.foreground
            font.pixelSize: 13
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component Switch: Rectangle {
        id: switchRoot
        property bool checked: false
        property string label: ""
        signal toggled()
        implicitWidth: 40
        implicitHeight: 22
        radius: height / 2
        color: checked ? Theme.Colors.accent : Theme.Colors.activeWorkspace
        opacity: enabled ? 1 : 0.4
        activeFocusOnTab: true
        border.width: activeFocus ? 2 : 0
        border.color: Theme.Colors.foreground
        Accessible.role: Accessible.CheckBox
        Accessible.name: label
        Accessible.checked: checked
        Keys.onReturnPressed: toggled()
        Keys.onSpacePressed: toggled()

        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 3
            x: switchRoot.checked ? switchRoot.width - width - 3 : 3
            color: switchRoot.checked ? Theme.Colors.background : Theme.Colors.foreground
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: switchMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: switchRoot.toggled()
        }
        Components.Tooltip {
            text: switchRoot.label
            shown: switchMouse.containsMouse
        }
    }

    component SectionLabel: Text {
        width: parent.width
        color: Theme.Colors.foreground
        opacity: 0.6
        font.pixelSize: 11
        font.bold: true
        topPadding: 4
    }

    component DeviceRow: Rectangle {
        id: row
        required property var modelData
        readonly property var device: modelData
        readonly property bool expanded: root.expandedAddress === device.address
        readonly property bool busy: device.pairing || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting

        width: parent.width
        height: 48 + (expanded ? actions.height + 8 : 0)
        radius: 6
        color: device.connected || expanded || rowMouse.containsMouse ? Theme.Colors.activeWorkspace : Theme.Colors.transparent
        clip: true
        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

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
            y: 14
            action: row.device.connected ? "bluetoothConnected" : "bluetooth"
            iconColor: row.device.connected ? Theme.Colors.accent : Theme.Colors.foreground
        }

        Column {
            x: 38
            y: 7
            width: parent.width - x - primaryButton.width - 16
            spacing: 2

            Text {
                width: parent.width
                text: row.device.name
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.Colors.foreground
                font.pixelSize: 13
            }
            Text {
                width: parent.width
                text: root.stateText(row.device)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.Colors.foreground
                opacity: 0.6
                font.pixelSize: 11
            }
        }

        Button {
            id: primaryButton
            anchors.right: parent.right
            anchors.rightMargin: 8
            y: 9
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
            x: 38
            y: 48
            spacing: 6
            visible: row.expanded

            Button {
                label: row.device.trusted ? "Untrust" : "Trust"
                onClicked: row.device.trusted = !row.device.trusted
            }
            Button {
                label: row.device.blocked ? "Unblock" : "Block"
                onClicked: row.device.blocked = !row.device.blocked
            }
            Button {
                label: "Forget"
                onClicked: root.forget(row.device)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.Colors.background

        // Keep clicks in the menu from reaching the outside-dismissal surface.
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8
            focus: root.active
            Keys.onEscapePressed: root.closeRequested()

            Row {
                width: parent.width
                height: 32
                spacing: 8

                Text {
                    width: parent.width - powerSwitch.width - closeButton.width - 16
                    height: parent.height
                    text: "Bluetooth"
                    color: Theme.Colors.foreground
                    font.pixelSize: 16
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
                Switch {
                    id: powerSwitch
                    anchors.verticalCenter: parent.verticalCenter
                    label: root.powered ? "Turn Bluetooth off" : "Turn Bluetooth on"
                    checked: root.powered
                    enabled: Services.Bluetooth.available
                        && root.adapter?.state !== BluetoothAdapterState.Blocked
                    onToggled: Services.Bluetooth.setEnabled(!root.powered)
                }
                Components.IconButton {
                    id: closeButton
                    width: 32
                    height: 32
                    icon: "close"
                    tooltip: "Close Bluetooth menu (Esc)"
                    onClicked: root.closeRequested()
                }
            }

            Text {
                width: parent.width
                visible: !root.powered
                text: !Services.Bluetooth.available ? "No Bluetooth adapter found."
                    : root.adapter?.state === BluetoothAdapterState.Blocked ? "Bluetooth is blocked by rfkill (airplane mode)."
                    : root.adapter?.state === BluetoothAdapterState.Enabling ? "Turning on…"
                    : "Bluetooth is off."
                wrapMode: Text.Wrap
                color: Theme.Colors.foreground
                opacity: 0.7
                font.pixelSize: 12
            }

            Row {
                width: parent.width
                height: 30
                spacing: 8
                visible: root.powered

                Text {
                    width: parent.width - discoverableSwitch.width - scanButton.width - 16
                    height: parent.height
                    text: "Visible as " + (root.adapter?.name ?? "")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.Colors.foreground
                    opacity: root.adapter?.discoverable ? 0.9 : 0.5
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                }
                Switch {
                    id: discoverableSwitch
                    anchors.verticalCenter: parent.verticalCenter
                    label: root.adapter?.discoverable ? "Hide from other devices" : "Make visible to other devices"
                    checked: root.adapter?.discoverable ?? false
                    onToggled: root.adapter.discoverable = !root.adapter.discoverable
                }
                Button {
                    id: scanButton
                    label: Services.Bluetooth.discovering ? "Stop scan" : "Scan"
                    onClicked: {
                        root.scanRequested = !Services.Bluetooth.discovering
                        Services.Bluetooth.setDiscovering(root.scanRequested)
                    }
                }
            }

            Text {
                width: parent.width
                text: !Services.Bluetooth.agentRunning ? "Pairing agent is not running; PIN pairing may fail." : root.message
                textFormat: Text.PlainText
                visible: text.length > 0 && root.powered
                wrapMode: Text.Wrap
                color: Theme.Colors.foreground
                opacity: 0.7
                font.pixelSize: 12
            }

            // Pairing prompt from the BlueZ agent.
            Rectangle {
                width: parent.width
                height: prompt.implicitHeight + 24
                radius: 8
                visible: root.request !== null
                color: Theme.Colors.activeWorkspace
                border.width: 1
                border.color: Theme.Colors.accent

                Column {
                    id: prompt
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 8

                    Text {
                        width: parent.width
                        text: {
                            const request = root.request
                            if (!request)
                                return ""
                            const name = request.name
                            switch (request.type) {
                            case "pin": return "Enter the PIN code for " + name + "."
                            case "passkey": return "Enter the passkey shown on " + name + "."
                            case "confirm": return "Confirm that " + name + " shows this passkey:"
                            case "authorize": return name + " wants to pair with this computer."
                            case "service": return name + " wants to use a Bluetooth service."
                            case "display-pin":
                            case "display-passkey": return "Type this code on " + name + ", then press Enter on it:"
                            }
                            return name
                        }
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: Theme.Colors.foreground
                        font.pixelSize: 13
                    }
                    Text {
                        width: parent.width
                        visible: text.length > 0
                        text: root.request?.passkey ?? ""
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.Colors.accent
                        font.pixelSize: 28
                        font.bold: true
                        font.letterSpacing: 4
                    }
                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: 6
                        visible: root.needsValue
                        color: Theme.Colors.background

                        TextInput {
                            id: valueInput
                            anchors.fill: parent
                            anchors.margins: 8
                            color: Theme.Colors.foreground
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
                            anchors.centerIn: parent
                            text: root.request?.type === "passkey" ? "6-digit passkey" : "PIN code (often 0000 or 1234)"
                            visible: !valueInput.text && !valueInput.activeFocus
                            color: Theme.Colors.foreground
                            opacity: 0.5
                            font.pixelSize: 11
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 8
                        Button {
                            label: root.request?.type.startsWith("display-") ? "Cancel pairing"
                                : root.request?.type === "confirm" ? "Doesn't match" : "Cancel"
                            onClicked: root.cancelPrompt()
                        }
                        Button {
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

            Flickable {
                id: viewport
                width: parent.width
                height: Math.min(lists.implicitHeight, Math.max(120, root.maximumHeight - 220))
                visible: root.powered
                contentWidth: width
                contentHeight: lists.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: lists
                    width: viewport.width
                    spacing: 4

                    SectionLabel {
                        text: "MY DEVICES"
                        visible: root.pairedDevices.length > 0
                    }
                    Repeater {
                        model: root.pairedDevices
                        delegate: DeviceRow {}
                    }

                    SectionLabel {
                        text: Services.Bluetooth.discovering ? "AVAILABLE DEVICES · SCANNING…" : "AVAILABLE DEVICES"
                    }
                    Text {
                        width: parent.width
                        height: 36
                        visible: root.availableDevices.length === 0
                        text: Services.Bluetooth.discovering ? "Looking for devices in pairing mode…" : "Press Scan to find nearby devices."
                        color: Theme.Colors.foreground
                        opacity: 0.6
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                    }
                    Repeater {
                        model: root.availableDevices
                        delegate: DeviceRow {}
                    }
                }
            }

            Button {
                label: "Advanced settings…"
                onClicked: {
                    root.closeRequested()
                    Quickshell.execDetached(["kitty", "--class", "bluetooth-settings", "-e", "bluetoothctl"])
                }
            }
        }
    }
}
