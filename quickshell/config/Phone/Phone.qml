import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme" as Theme
import "../Services" as Services

Scope {
    id: root

    property bool opened: false
    property var chosenScreen: Quickshell.screens[0] ?? null
    property Item chat: null
    readonly property real visibleShare: 0.9
    readonly property real horizontalCenterShare: 0.7
    readonly property real bounce: 34
    readonly property real pocketRoll: 12

    function show() {
        chosenScreen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null
        opened = true
    }
    function close() {
        if (!opened) return
        opened = false
        const address = Hyprland.activeToplevel?.address
        if (address)
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + address + "\" })")
    }

    onOpenedChanged: {
        if (opened) {
            exitAnim.stop()
            stage.lift = Math.min(stage.lift, stage.hiddenLift)
            enterAnim.restart()
            Services.Mei.refresh()
            Qt.callLater(() => root.chat?.focusInput())
        } else {
            enterAnim.stop()
            stage.exitPeak = stage.lift > 20 ? stage.lift : -bounce * 0.7
            exitAnim.restart()
        }
    }

    IpcHandler {
        target: "phone"
        function toggle(): void { if (root.opened) root.close(); else root.show() }
        function open(): void { root.show() }
        function close(): void { root.close() }
        function state(): string { return JSON.stringify({ open: root.opened }) }
    }

    QtObject {
        id: stage
        property real lift: hiddenLift
        property real tilt: 1
        property real exitPeak: 0
        readonly property real hiddenLift: win.implicitHeight + phone.height * 0.15
    }

    ParallelAnimation {
        id: enterAnim
        SequentialAnimation {
            NumberAnimation { target: stage; property: "lift"; to: -root.bounce; duration: 340; easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "lift"; to: 0; duration: 170; easing.type: Easing.InOutSine }
            NumberAnimation { target: stage; property: "lift"; to: -root.bounce * 0.14; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: stage; property: "lift"; to: 0; duration: 110; easing.type: Easing.InQuad }
        }
        NumberAnimation {
            target: stage; property: "tilt"; to: 0; duration: 820
            easing { type: Easing.OutElastic; amplitude: 1; period: 0.4 }
        }
    }

    ParallelAnimation {
        id: exitAnim
        SequentialAnimation {
            NumberAnimation { target: stage; property: "lift"; to: stage.exitPeak; duration: 130; easing.type: Easing.OutQuad }
            NumberAnimation { target: stage; property: "lift"; to: stage.hiddenLift; duration: 340; easing.type: Easing.InCubic }
        }
        NumberAnimation { target: stage; property: "tilt"; to: 1; duration: 440; easing.type: Easing.InQuad }
    }

    PanelWindow {
        id: win
        readonly property real headroom: root.bounce + phone.height * 0.12
        screen: root.chosenScreen
        visible: root.opened || exitAnim.running
        anchors { bottom: true; left: true; right: true }
        implicitHeight: phone.height * root.visibleShare + headroom
        exclusiveZone: 0
        color: "transparent"
        mask: Region { item: phone }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-phone"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        PhoneBody {
            id: phone
            height: Math.round(Math.min((win.screen?.height ?? 1080) * 0.8, 860))
            width: Math.round(height * 0.49)
            x: win.width * root.horizontalCenterShare - width / 2
            y: win.headroom + stage.lift
            transform: Rotation {
                origin.x: phone.width / 2
                origin.y: phone.height
                angle: root.pocketRoll * stage.tilt
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
                color: "black"

                Rectangle {
                    id: glassShape
                    anchors.fill: parent
                    radius: screenGlass.radius
                    visible: false
                    layer.enabled: true
                }

                Chat {
                    id: chat
                    anchors.fill: parent
                    active: root.opened
                    hiddenBottom: body.height * (1 - root.visibleShare) - body.bezel
                    onDismissed: root.close()
                    Component.onCompleted: root.chat = chat
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: glassShape
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                }
            }
        }
    }
}
