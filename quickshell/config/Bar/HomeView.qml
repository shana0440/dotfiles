import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    property bool active: false
    property date today: new Date()
    readonly property alias calendar: calendar
    signal closeRequested()

    implicitWidth: calendar.implicitWidth + clockFace.implicitWidth
    implicitHeight: home.implicitHeight + 12

    Column {
        id: home
        width: parent.width

        Row {
            Calendar {
                id: calendar
                today: root.today
                onCloseRequested: root.closeRequested()
            }
            ClockFace {
                id: clockFace
                active: root.active
            }
        }

        Rectangle {
            x: 20
            width: parent.width - 40
            height: 1
            color: Theme.Colors.ring
        }

        Item {
            id: weather
            readonly property string detail: !Services.Weather.loaded ? "Unavailable"
                : [Services.Weather.place, "H " + Services.Weather.high + "° L " + Services.Weather.low + "°"]
                    .filter(part => part.length > 0).join(" · ")

            x: 12
            width: parent.width - 24
            height: 48
            Accessible.role: Accessible.StaticText
            Accessible.name: weatherTitle.text + ", " + detail

            Components.Icon {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 4
                width: 16
                height: 16
                action: Services.Weather.loaded ? Services.Weather.icon : "weatherCloudy"
            }
            Text {
                id: weatherTitle
                x: 36
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 4
                width: Math.min(implicitWidth, parent.width - 36 - weatherDetail.width - 16)
                text: !Services.Weather.loaded ? "Weather"
                    : Services.Weather.temperature + "° " + Services.Weather.condition
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.Colors.foreground
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 13
            }
            Text {
                id: weatherDetail
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 4
                text: weather.detail
                textFormat: Text.PlainText
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 12
            }
        }
    }
}
