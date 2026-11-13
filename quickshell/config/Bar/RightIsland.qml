import QtQuick
import "../Theme" as Theme
import "../Components" as Components

Components.Island {
    id: root

    property string mode: "default"
    property real availableHeight: 720
    property alias inputItem: inputIndicator.inputItem
    readonly property bool expanded: mode !== "default"
    // IME actions must run while the editor keeps its input context focused.
    readonly property bool keyboardFocusRequired: expanded && mode !== "input"
    readonly property bool confirming: mode === "power" && menu.confirming

    activeView: mode === "input" ? inputMenu : mode === "power" ? menu : defaultContent
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

            Rectangle {
                width: 40
                height: 32
                radius: 8
                color: powerMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent

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
        InputMethodMenu {
            id: inputMenu
            active: root.mode === "input"
            inputItem: inputIndicator.inputItem
            currentDescription: inputIndicator.description
            onCloseRequested: root.close()
        }
    ]
}
