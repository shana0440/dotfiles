import QtQuick
import "../Theme" as Theme
import "../Components" as Components

Components.Island {
    id: root

    property string mode: "default"
    property alias inputItem: inputIndicator.inputItem
    readonly property bool expanded: mode !== "default"
    // IME actions must run while the editor keeps its input context focused.
    readonly property bool keyboardFocusRequired: expanded && mode !== "input"
    readonly property bool confirming: mode === "power" && menu.confirming

    activeView: mode === "input" ? inputMenu : mode === "wifi" ? wifiMenu : mode === "power" ? menu : mode === "system" ? systemStatus : defaultContent
    alignment: Qt.AlignRight
    overflowView: defaultContent

    function close() {
        mode = "default"
        menu.cancel()
    }

    views: [
        Row {
            id: defaultContent
            spacing: 4

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
        SystemStatus {
            id: systemStatus
            active: root.mode === "system"
            onCloseRequested: root.close()
        },
        PowerMenu {
            id: menu
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
