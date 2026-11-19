import QtQuick
import "../Theme" as Theme

Rectangle {
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
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: checked
    Keys.onReturnPressed: toggled()
    Keys.onSpacePressed: toggled()

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        visible: toggle.activeFocus
        color: Theme.Colors.transparent
        border.width: 2
        border.color: Theme.Colors.muted
    }

    Rectangle {
        y: 3
        x: knob.value
        width: 16
        height: 16
        radius: 8
        color: toggle.checked ? Theme.Colors.background : Theme.Colors.foreground

        Spring {
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
    Tooltip {
        text: toggle.label
        shown: toggleMouse.containsMouse
    }
}
