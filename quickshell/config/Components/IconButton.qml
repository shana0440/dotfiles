import QtQuick
import "../Theme" as Theme

Rectangle {
    id: root

    property string icon: ""
    property string tooltip: ""
    property color iconColor: Theme.Colors.foreground
    property int iconSize: 20
    property bool iconFilled: false
    property bool highlighted: false
    // A selected tab keeps the hover fill.
    property bool selected: false
    signal clicked()

    implicitWidth: 36
    implicitHeight: 36
    radius: 8
    // Highlighted is Ding's primary action: the foreground fills it and the glyph inverts.
    color: highlighted
        ? (mouse.containsMouse ? Qt.tint(Theme.Colors.foreground, "#2e0c0c0d") : Theme.Colors.foreground)
        : selected || mouse.containsMouse || activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: tooltip
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Icon {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        action: root.icon
        iconColor: root.highlighted ? Theme.Colors.background : root.iconColor
        filled: root.iconFilled
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Tooltip {
        text: root.tooltip
        shown: mouse.containsMouse || root.activeFocus
        alignment: Qt.AlignHCenter
    }
}
