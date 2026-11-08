import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Components.Island {
    id: root

    property string mode: "default"
    property real availableHeight: 720
    property alias inputItem: inputIndicator.inputItem
    readonly property bool expanded: mode !== "default"
    // IME actions must run while the editor keeps its input context focused.
    readonly property bool keyboardFocusRequired: expanded && mode !== "input"
    readonly property bool confirming: mode === "power" && menu.confirming

    activeView: mode === "input" ? inputMenu : mode === "wifi" ? wifiMenu : mode === "bluetooth" ? bluetoothMenu : mode === "power" ? menu : mode === "system" ? systemStatus : mode === "audio" ? audioMenu : mode === "voice" ? voiceMenu : defaultContent
    alignment: Qt.AlignRight
    overflowView: defaultContent

    function close() {
        mode = "default"
        menu.cancel()
    }

    // Pairing prompts can arrive while the menu is closed, e.g. from a remote device.
    Connections {
        target: Services.Bluetooth
        function onRequestChanged() {
            if (Services.Bluetooth.request)
                root.mode = "bluetooth"
        }
    }

    views: [
        Row {
            id: defaultContent
            spacing: 4

            Components.IconButton {
                width: 40
                height: 32
                icon: "audio"
                tooltip: "Select audio output device"
                onClicked: root.mode = "audio"
            }

            Components.IconButton {
                width: 40
                height: 32
                icon: "microphone"
                tooltip: "Select voice input device (microphone)"
                onClicked: root.mode = "voice"
            }

            InputMethodIndicator {
                id: inputIndicator
                onClicked: root.mode = "input"
            }

            Components.IconButton {
                width: 40
                height: 32
                icon: "systemStatus"
                tooltip: "System status"
                onClicked: root.mode = "system"
            }

            BluetoothIndicator {
                onClicked: root.mode = "bluetooth"
            }

            Wifi {
                id: wifiStatus
                onClicked: root.mode = "wifi"
            }

            Rectangle {
                width: 40
                height: 32
                radius: 8
                color: powerMouse.containsMouse ? Theme.Colors.activeWorkspace : Theme.Colors.transparent

                Components.Icon {
                    anchors.centerIn: parent
                    action: "poweroff"
                }

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.mode = "power"
                }

                Components.Tooltip {
                    text: "Power"
                    shown: powerMouse.containsMouse
                }
            }
        },
        AudioDeviceMenu {
            id: audioMenu
            maximumHeight: root.availableHeight
            onCloseRequested: root.close()
        },
        AudioDeviceMenu {
            id: voiceMenu
            input: true
            maximumHeight: root.availableHeight
            onCloseRequested: root.close()
        },
        SystemStatus {
            id: systemStatus
            maximumHeight: root.availableHeight
            active: root.mode === "system"
            onCloseRequested: root.close()
        },
        PowerMenu {
            id: menu
            onCloseRequested: root.close()
        },
        BluetoothMenu {
            id: bluetoothMenu
            active: root.mode === "bluetooth"
            maximumHeight: root.availableHeight
            onCloseRequested: root.close()
        },
        WifiMenu {
            id: wifiMenu
            active: root.mode === "wifi"
            onCloseRequested: root.close()
            onConnectionChanged: wifiStatus.refreshStatus()
        },
        InputMethodMenu {
            id: inputMenu
            active: root.mode === "input"
            inputItem: inputIndicator.inputItem
            currentDescription: inputIndicator.description
            onCloseRequested: root.close()
        }
    ]
}
