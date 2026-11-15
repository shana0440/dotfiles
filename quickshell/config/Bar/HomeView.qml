import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    property bool active: false
    property date today: new Date()
    readonly property alias calendar: calendar
    property bool inputMethodsOpen: false
    signal closeRequested()

    readonly property int rowHeight: 40

    implicitWidth: calendar.implicitWidth + clockFace.implicitWidth
    implicitHeight: inputMethodsOpen ? inputPage.implicitHeight + 40 : home.implicitHeight + 12
    clip: true

    onActiveChanged: inputMethodsOpen = false

    function navigateBack() {
        inputMethodsOpen = false
    }

    function navigateForward() {
        inputMethodsOpen = true
    }

    InputMethodState {
        id: inputMethod
    }

    Components.Spring {
        id: pageSpring
        to: root.inputMethodsOpen ? 1 : 0
        stiffness: Theme.Motion.stackStiffness
        damping: Theme.Motion.stackDamping
        precision: 0.002
    }

    component InfoRow: Rectangle {
        id: row
        property string icon: ""
        property string title: ""
        property string detail: ""
        property bool opens: false
        signal clicked()

        width: parent.width
        height: root.rowHeight
        radius: 8
        color: opens && mouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent
        Accessible.role: opens ? Accessible.Button : Accessible.StaticText
        Accessible.name: title + ", " + detail

        Components.Icon {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            action: row.icon
        }
        Text {
            x: 36
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - 36 - details.width - 16)
            text: row.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 13
        }
        Row {
            id: details
            anchors.right: parent.right
            anchors.rightMargin: row.opens ? 4 : 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.detail
                textFormat: Text.PlainText
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 12
            }
            Components.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                visible: row.opens
                action: "forward"
                iconColor: Theme.Colors.muted
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: row.opens
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }

    Column {
        id: home
        x: -24 * pageSpring.value
        width: parent.width
        opacity: 1 - pageSpring.value
        visible: opacity > 0
        enabled: !root.inputMethodsOpen

        Row {
            Calendar {
                id: calendar
                today: root.today
                onCloseRequested: root.closeRequested()
            }
            ClockFace {
                id: clockFace
                active: root.active && !root.inputMethodsOpen

                Components.IconButton {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    width: 32
                    height: 32
                    iconSize: 18
                    icon: Theme.Colors.transparentTheme ? "themeTransparent" : "themeDark"
                    iconColor: Theme.Colors.foreground
                    tooltip: Theme.Colors.transparentTheme ? "Use dark theme" : "Use transparent theme"
                    onClicked: Theme.Colors.toggleTheme()
                }
            }
        }

        Rectangle {
            x: 20
            width: parent.width - 40
            height: 1
            color: Theme.Colors.ring
        }

        Column {
            x: 12
            width: parent.width - 24
            topPadding: 8
            spacing: 2

            InfoRow {
                icon: Services.Weather.loaded ? Services.Weather.icon : "weatherCloudy"
                title: !Services.Weather.loaded ? "Weather"
                    : Services.Weather.temperature + "° " + Services.Weather.condition
                detail: !Services.Weather.loaded ? "Unavailable"
                    : [Services.Weather.place, "H " + Services.Weather.high + "° L " + Services.Weather.low + "°"]
                        .filter(part => part.length > 0).join(" · ")
            }
            InfoRow {
                icon: "keyboard"
                title: "Input method"
                detail: inputMethod.description
                opens: true
                onClicked: root.inputMethodsOpen = true
            }
        }
    }

    Column {
        id: inputPage
        x: 20 + 24 * (1 - pageSpring.value)
        y: 20
        width: parent.width - 40
        spacing: 12
        opacity: pageSpring.value
        visible: opacity > 0
        enabled: root.inputMethodsOpen

        Item {
            width: parent.width
            height: 32

            Components.IconButton {
                id: back
                x: -6
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                iconSize: 18
                icon: "back"
                tooltip: "Back to home"
                onClicked: root.inputMethodsOpen = false
            }
            Column {
                anchors.left: back.right
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Input method"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    text: inputMethod.description
                    textFormat: Text.PlainText
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }
            }
        }

        InputMethodList {
            x: -8
            width: parent.width + 16
            active: root.active && root.inputMethodsOpen
            inputItem: inputMethod.inputItem
        }
    }
}
