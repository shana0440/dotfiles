import QtQuick

MouseArea {
    id: toggle
    property real pt: 1
    property bool on: false
    property bool busy: false
    signal toggled
    width: 51 * pt
    height: 31 * pt
    enabled: !busy
    cursorShape: Qt.PointingHandCursor
    onClicked: toggled()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: toggle.on ? Look.switchOn : Look.switchOff
        Behavior on color { ColorAnimation { duration: 180 } }
    }
    Rectangle {
        readonly property real inset: 2 * toggle.pt
        x: toggle.on ? toggle.width - width - inset : inset
        y: inset
        width: toggle.height - 2 * inset
        height: width
        radius: width / 2
        color: "white"
        border { width: 0.5; color: Qt.rgba(0, 0, 0, 0.04) }
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
    }
}
