import QtQuick
import "../Theme" as Theme
import "../Components" as Components

Components.Island {
    id: root

    property string mode: "default"
    readonly property bool expanded: mode !== "default"
    readonly property bool confirming: mode === "power" && menu.confirming

    activeView: mode === "wifi" ? wifiMenu : mode === "power" ? menu : defaultContent
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
        PowerMenu {
            id: menu
            onCloseRequested: root.close()
        },
        WifiMenu {
            id: wifiMenu
            active: root.mode === "wifi"
            onCloseRequested: root.close()
            onConnectionChanged: wifiStatus.refreshStatus()
        }
    ]
}
