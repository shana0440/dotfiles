import QtQuick
import Quickshell
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    property bool active: false
    property int maximumHeight: 560
    property WifiController wifi
    property string selectedSsid: ""
    signal backRequested()
    signal closeRequested()

    readonly property int rowHeight: 40
    readonly property int rowSpacing: 2

    implicitWidth: 480
    implicitHeight: wifiPage.implicitHeight + 40

    onActiveChanged: {
        clearSelection()
        if (active)
            wifi.refresh()
    }

    Connections {
        target: root.wifi
        function onConnectionChanged() {
            root.clearSelection()
        }
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


    Column {
        id: wifiPage
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 12

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
                tooltip: "Back to settings"
                onClicked: root.backRequested()
            }
            Column {
                anchors.left: back.right
                anchors.leftMargin: 2
                anchors.right: controls.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Wi-Fi"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    width: parent.width
                    text: !wifi.enabled ? "Off"
                        : wifi.scanning && wifi.networks.count === 0 ? "Scanning"
                        : (wifi.current ? "Connected to " + wifi.current.ssid : "Not connected")
                            + " \u00b7 " + wifi.networks.count + " nearby"
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
                spacing: 4

                Components.Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    label: wifi.enabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
                    checked: wifi.enabled
                    enabled: !wifi.busy
                    onToggled: wifi.setEnabled(!wifi.enabled)
                }
                Item {
                    width: 4
                    height: 1
                }
                Components.IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    iconSize: 16
                    icon: "reboot"
                    tooltip: wifi.scanning ? "Scanning" : "Scan again"
                    enabled: wifi.enabled && !wifi.scanning && !wifi.busy
                    onClicked: wifi.refresh()
                }
                Components.IconButton {
                    anchors.verticalCenter: parent.verticalCenter
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

        Text {
            leftPadding: 4
            visible: !wifi.enabled
            text: wifi.message || "Turn Wi-Fi on to see nearby networks"
            color: Theme.Colors.muted
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 12
        }

        Column {
            id: networksSection
            width: parent.width
            spacing: 8
            visible: wifi.enabled

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
                        Keys.onEscapePressed: root.clearSelection()
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

}
