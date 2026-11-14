import QtQuick
import "../Theme" as Theme
import "../Components" as Components

// The current input method, flowing out of the island beside it like the side dots.
// Clicking opens the dashboard's input method page.
Components.MergeableCircle {
    id: root

    signal clicked()
    width: Math.max(40, label.implicitWidth + 24)
    Accessible.role: Accessible.Button
    Accessible.name: inputMethod.description + "; choose input method"
    activeFocusOnTab: shown
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    InputMethodState {
        id: inputMethod
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: mouse.containsMouse || root.activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: inputMethod.label
        textFormat: Text.PlainText
        opacity: inputMethod.inputItem ? 1 : 0.5
        color: Theme.Colors.foreground
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        font.pixelSize: 14
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Components.Tooltip {
        text: inputMethod.description
        shown: mouse.containsMouse || root.activeFocus
        alignment: Qt.AlignHCenter
    }
}
