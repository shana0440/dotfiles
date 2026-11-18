import QtQuick
import "../../Theme" as Theme
import "../../Components" as Components
import ".." as Phone

Rectangle {
    id: bar

    property real pt: 1
    property bool active: false
    property string title
    property string backLabel
    signal back

    height: 104 * pt
    color: Qt.alpha(Look.barFill, 0.96)

    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        color: Look.hairline
    }

    Phone.StatusBar {
        id: statusBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 54 * bar.pt
        pt: bar.pt
        active: bar.active
        ink: Look.ink
    }

    MouseArea {
        id: backButton
        anchors { left: parent.left; leftMargin: 6 * bar.pt; top: statusBar.bottom; topMargin: 12 * bar.pt }
        width: backLabel.width
        height: backLabel.height
        cursorShape: Qt.PointingHandCursor
        onClicked: bar.back()

        Row {
            id: backLabel
            opacity: backButton.pressed ? 0.4 : 1
            spacing: 2 * bar.pt
            Components.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 26 * bar.pt
                height: width
                action: "back"
                iconColor: Look.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.backLabel
                color: Look.accent
                font { family: Theme.Fonts.family; pixelSize: 17 * bar.pt }
            }
        }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: backButton.verticalCenter }
        width: Math.min(implicitWidth, bar.width - 2 * (backButton.x + backButton.width) - 16 * bar.pt)
        elide: Text.ElideRight
        text: bar.title
        color: Look.ink
        font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 17 * bar.pt }
    }
}
