import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme" as Theme
import "../Components" as Components

Scope {
    id: root

    property bool opened: false
    property var chosenScreen: Quickshell.screens[0] ?? null
    readonly property real visibleShare: 0.75
    readonly property real horizontalCenterShare: 0.75

    function show() {
        chosenScreen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null
        opened = true
    }
    function close() { opened = false }

    IpcHandler {
        target: "phone"
        function toggle(): void { if (root.opened) root.close(); else root.show() }
        function open(): void { root.show() }
        function close(): void { root.close() }
        function state(): string { return JSON.stringify({ open: root.opened }) }
    }

    PanelWindow {
        id: win
        screen: root.chosenScreen
        visible: root.opened || phone.y < win.height
        anchors { bottom: true; left: true }
        margins.left: Math.max(0, (screen?.width ?? 0) * root.horizontalCenterShare - implicitWidth / 2)
        implicitWidth: phone.width + phone.shadowRoom * 2
        implicitHeight: phone.height * root.visibleShare + phone.shadowRoom
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-phone"

        PhoneBody {
            id: phone
            readonly property real shadowRoom: 24
            height: Math.round(Math.min((win.screen?.height ?? 1080) * 0.86, 880))
            width: Math.round(height * 0.49)
            x: shadowRoom
            y: root.opened ? phone.shadowRoom : win.height
            Behavior on y {
                NumberAnimation {
                    duration: root.opened ? 420 : 300
                    easing.type: root.opened ? Easing.OutCubic : Easing.InCubic
                }
            }
        }
    }

    component PhoneBody: Item {
        id: body
        readonly property real bezel: Math.round(width * 0.035)
        readonly property real cornerRadius: width * 0.17

        RectangularShadow {
            anchors.fill: frame
            radius: frame.radius
            offset.y: 8
            blur: 28
            spread: 0
            color: Theme.Colors.shadow
        }

        Repeater {
            model: [
                { side: "left", top: 0.15, length: 0.04 },
                { side: "left", top: 0.22, length: 0.07 },
                { side: "left", top: 0.31, length: 0.07 },
                { side: "right", top: 0.25, length: 0.11 }
            ]
            Rectangle {
                required property var modelData
                width: 4
                height: body.height * modelData.length
                radius: 2
                x: modelData.side === "left" ? -2 : body.width - 2
                y: body.height * modelData.top
                color: "#3a3a3c"
            }
        }

        Rectangle {
            id: frame
            anchors.fill: parent
            radius: body.cornerRadius
            color: "#0a0a0b"
            border.width: 2
            border.color: "#48484a"

            Rectangle {
                id: screenGlass
                anchors.fill: parent
                anchors.margins: body.bezel
                radius: body.cornerRadius - body.bezel
                clip: true
                gradient: Gradient {
                    GradientStop { position: 0; color: "#1d2b3a" }
                    GradientStop { position: 0.55; color: "#141a22" }
                    GradientStop { position: 1; color: "#0c0c0d" }
                }

                PhoneScreen { anchors.fill: parent }
            }
        }
    }

    component PhoneScreen: Item {
        id: screenArea
        readonly property date now: clock.date
        readonly property real unit: width / 100

        SystemClock {
            id: clock
            enabled: root.opened
            precision: SystemClock.Minutes
        }

        Rectangle {
            id: island
            anchors { top: parent.top; topMargin: screenArea.unit * 3; horizontalCenter: parent.horizontalCenter }
            width: screenArea.unit * 32
            height: screenArea.unit * 9.5
            radius: height / 2
            color: "black"
        }

        Text {
            anchors { verticalCenter: island.verticalCenter; horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: -screenArea.width * 0.3 }
            text: Qt.formatTime(screenArea.now, "h:mm")
            color: Theme.Colors.foreground
            font { family: Theme.Fonts.family; weight: Font.Bold; pixelSize: screenArea.unit * 4.6 }
        }

        Row {
            anchors { verticalCenter: island.verticalCenter; horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: screenArea.width * 0.3 }
            spacing: screenArea.unit * 1.4

            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: screenArea.unit * 0.4
                spacing: screenArea.unit * 0.5
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: screenArea.unit * 0.9
                        height: screenArea.unit * (1.4 + index * 0.8)
                        radius: width / 3
                        color: Theme.Colors.foreground
                    }
                }
            }
            Components.Icon {
                action: "wifi"
                width: screenArea.unit * 4.4
                height: width
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: screenArea.unit * 7
                height: screenArea.unit * 3.4
                Rectangle {
                    width: parent.width - screenArea.unit * 0.8
                    height: parent.height
                    radius: height * 0.3
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(Theme.Colors.foreground, 0.45)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: screenArea.unit * 0.5
                        radius: height * 0.25
                        color: Theme.Colors.foreground
                    }
                }
                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: screenArea.unit * 0.5
                    height: parent.height * 0.4
                    radius: width / 2
                    color: Qt.alpha(Theme.Colors.foreground, 0.45)
                }
            }
        }

        Column {
            anchors { top: island.bottom; topMargin: screenArea.unit * 12; horizontalCenter: parent.horizontalCenter }
            spacing: screenArea.unit * 1.5

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(screenArea.now, "dddd, MMMM d")
                color: Qt.alpha(Theme.Colors.foreground, 0.8)
                font { family: Theme.Fonts.family; weight: Theme.Fonts.weight; pixelSize: screenArea.unit * 5 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(screenArea.now, "h:mm")
                color: Theme.Colors.foreground
                font { family: Theme.Fonts.family; weight: Font.Bold; pixelSize: screenArea.unit * 24 }
            }
        }
    }
}
