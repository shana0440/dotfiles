import QtQuick
import "../Components" as Components
import "../Theme" as Theme

Components.IconButton {
    id: root

    required property string shortcutKey

    implicitWidth: 48
    implicitHeight: 44
    iconSize: 20

    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 2
        width: Math.max(14, keyLabel.implicitWidth + 7)
        height: 13
        radius: 3
        color: root.highlighted ? Theme.Colors.background : Theme.Colors.track

        Text {
            id: keyLabel
            anchors.centerIn: parent
            text: root.shortcutKey
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.pixelSize: 9
            font.weight: Font.DemiBold
        }
    }
}
