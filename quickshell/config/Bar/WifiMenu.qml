import QtQuick
import Quickshell
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    property bool active: false
    signal closeRequested()
    signal connectionChanged()
    property string selectedSsid: ""
    readonly property bool busy: wifi.busy

    implicitWidth: 340
    implicitHeight: content.implicitHeight + 24
    focus: active

    onActiveChanged: {
        password.text = ""
        selectedSsid = ""
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
        if (!selectedSsid || busy)
            return
        wifi.connect(selectedSsid, password.text)
        password.text = ""
    }

    function disconnectNetwork(device) {
        if (!device || busy)
            return
        selectedSsid = ""
        password.text = ""
        wifi.disconnect(device)
    }

    WifiController {
        id: wifi
        active: root.active
        onConnectionChanged: {
            root.selectedSsid = ""
            root.connectionChanged()
        }
    }

    component Button: Rectangle {
        property string label: ""
        signal clicked()
        implicitWidth: buttonText.implicitWidth + 20
        implicitHeight: 30
        radius: 6
        color: buttonMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent
        opacity: enabled ? 1 : 0.4
        Accessible.role: Accessible.Button
        Accessible.name: label

        Text {
            id: buttonText
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            anchors.centerIn: parent
            text: parent.label
            color: Theme.Colors.foreground
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

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.Colors.background

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
                height: 30

                Text {
                    font.family: Theme.Fonts.family
                    width: parent.width - refreshButton.width - closeButton.width
                    height: parent.height
                    text: "Wi-Fi"
                    color: Theme.Colors.foreground
                    font.pixelSize: 16
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
                Button {
                    id: refreshButton
                    label: wifi.scanning ? "Scanning…" : "Refresh"
                    enabled: !wifi.scanning && !root.busy
                    onClicked: wifi.refresh()
                }
                Button {
                    id: closeButton
                    label: "×"
                    onClicked: root.closeRequested()
                }
            }

            Text {
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                width: parent.width
                text: wifi.message
                textFormat: Text.PlainText
                visible: text.length > 0
                wrapMode: Text.Wrap
                color: Theme.Colors.foreground
                opacity: 0.7
                font.pixelSize: 12
            }

            ListView {
                id: networkList
                width: parent.width
                height: 220
                clip: true
                spacing: 4
                model: wifi.networks
                enabled: !root.busy

                delegate: Rectangle {
                    required property string ssid
                    required property bool active
                    required property int strength
                    required property string security
                    required property string device

                    width: networkList.width
                    height: 48
                    radius: 6
                    color: active || networkMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent

                    Components.Icon {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        action: parent.strength >= 67 ? "wifi" : parent.strength >= 34 ? "wifiHigh" : "wifiLow"
                    }

                    Column {
                        x: 38
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 38 - (active ? disconnectButton.width + 16 : 52)
                        spacing: 2

                        Text {
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            width: parent.width
                            text: ssid
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.Colors.foreground
                            font.pixelSize: 13
                        }
                        Text {
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            width: parent.width
                            text: active ? "Connected" : (!security || security === "--" ? "Open" : security)
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.Colors.foreground
                            opacity: 0.6
                            font.pixelSize: 11
                        }
                    }

                    Text {
                        font.family: Theme.Fonts.family
                        font.weight: Theme.Fonts.weight
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: strength + "%"
                        visible: !active
                        color: Theme.Colors.foreground
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: networkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!active)
                                root.selectNetwork(ssid, security)
                        }
                    }

                    Button {
                        id: disconnectButton
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Disconnect"
                        visible: active
                        onClicked: root.disconnectNetwork(device)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6
                visible: root.selectedSsid.length > 0

                Text {
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    width: parent.width
                    text: root.selectedSsid
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.Colors.foreground
                    font.pixelSize: 13
                }
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: Theme.Colors.surface

                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.margins: 8
                        echoMode: TextInput.Password
                        enabled: !root.busy
                        color: Theme.Colors.foreground
                        font.pixelSize: 13
                        selectByMouse: true
                        clip: true
                        onAccepted: root.connectSelected()
                    }
                    Text {
                        font.family: Theme.Fonts.family
                        font.weight: Theme.Fonts.weight
                        anchors.centerIn: parent
                        text: "Password (blank uses saved credentials)"
                        visible: !password.text && !password.activeFocus
                        color: Theme.Colors.foreground
                        opacity: 0.5
                        font.pixelSize: 11
                    }
                }
                Row {
                    spacing: 8
                    Button {
                        label: "Cancel"
                        enabled: !root.busy
                        onClicked: {
                            root.selectedSsid = ""
                            password.text = ""
                        }
                    }
                    Button {
                        label: wifi.connecting ? "Connecting…" : "Connect"
                        enabled: !root.busy
                        onClicked: root.connectSelected()
                    }
                }
            }

            Button {
                label: "Advanced settings…"
                enabled: !root.busy
                onClicked: {
                    root.closeRequested()
                    Quickshell.execDetached(["kitty", "--class", "wifi-settings", "-e", "nmtui"])
                }
            }
        }
    }
}
