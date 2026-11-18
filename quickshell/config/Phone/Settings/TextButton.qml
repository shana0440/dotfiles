import QtQuick
import "../../Theme" as Theme

Text {
    id: button
    property real pt: 1
    property string label
    property color tint: Look.accent
    signal clicked
    text: label
    color: tint
    opacity: buttonArea.pressed ? 0.4 : 1
    font { family: Theme.Fonts.family; pixelSize: 15 * pt }

    MouseArea {
        id: buttonArea
        anchors.fill: parent
        anchors.margins: -6 * button.pt
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
