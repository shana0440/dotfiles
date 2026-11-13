import QtQuick
import "../Components" as Components

Components.Island {
    id: root

    property string mode: "default"
    property real availableHeight: 720
    property alias inputItem: inputIndicator.inputItem
    readonly property bool expanded: mode !== "default"
    // IME actions must run while the editor keeps its input context focused.
    readonly property bool keyboardFocusRequired: expanded && mode !== "input"

    activeView: mode === "input" ? inputMenu : defaultContent
    alignment: Qt.AlignRight
    overflowView: defaultContent

    function close() {
        mode = "default"
    }

    views: [
        Row {
            id: defaultContent
            spacing: 4

            InputMethodIndicator {
                id: inputIndicator
                onClicked: root.mode = "input"
            }
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
