import QtQuick
import "../Components" as Components
import "../Services" as Services
import "../Theme" as Theme

// The current temperature, flowing out of the island beside it like the side dots.
// Clicking opens the dashboard's home tab, which shows the weather too.
Components.MergeableCircle {
    id: root

    signal clicked()
    available: Services.Weather.loaded
    width: content.implicitWidth + 20
    Accessible.role: Accessible.Button
    Accessible.name: tooltip.text
    activeFocusOnTab: shown
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: mouse.containsMouse || root.activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Components.Icon {
            anchors.verticalCenter: parent.verticalCenter
            action: Services.Weather.icon
            width: 16
            height: 16
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 14
            color: Theme.Colors.foreground
            text: Services.Weather.temperature + "°"
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Components.Tooltip {
        id: tooltip
        text: [Services.Weather.condition, Services.Weather.place,
            "Feels " + Services.Weather.feelsLike + "°",
            "H " + Services.Weather.high + "° L " + Services.Weather.low + "°"]
            .filter(part => part.length > 0).join(" · ")
        shown: mouse.containsMouse || root.activeFocus
        alignment: Qt.AlignHCenter
    }
}
