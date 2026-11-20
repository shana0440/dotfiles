import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme" as Theme
import "../Services" as Services
import "Settings" as Settings

Scope {
    id: root

    property bool opened: false
    property var chosenScreen: Quickshell.screens[0] ?? null
    property Item display: null
    readonly property real visibleShare: 0.9
    readonly property real horizontalCenterShare: 0.7
    readonly property real bounce: 34
    readonly property real pocketRoll: 12

    function show() {
        chosenScreen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null
        opened = true
    }
    function showChat() {
        if (display) display.stack = ["chat"]
        show()
        Qt.callLater(() => root.display?.focusCurrent())
    }
    function close() {
        if (!opened) return
        opened = false
    }

    readonly property bool raised: opened && !Services.Mei.choosingAvatar && !Services.ChatBackground.choosing

    onOpenedChanged: if (opened) Services.Mei.refresh()

    Binding {
        target: Services.Mei
        property: "chatInView"
        value: root.raised
    }

    Connections {
        target: Services.Mei
        function onOpenRequested() { root.showChat() }
    }
    onRaisedChanged: {
        if (raised) {
            exitAnim.stop()
            stage.lift = Math.min(stage.lift, stage.hiddenLift)
            enterAnim.restart()
            Qt.callLater(() => root.display?.focusCurrent())
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
        readonly property real hiddenLift: win.stageHeight + phone.height * 0.15
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

    Variants {
        model: Quickshell.screens.filter(screen => screen !== root.chosenScreen)

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.raised
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.close()
            }
        }
    }

    PanelWindow {
        id: win
        readonly property real headroom: root.bounce + phone.height * 0.12
        readonly property real stageHeight: phone.height * root.visibleShare + headroom
        screen: root.chosenScreen
        visible: root.raised || exitAnim.running
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region { item: root.raised ? outside : phone }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-phone"
        WlrLayershell.keyboardFocus: root.raised && !Services.Capture.ownsInput
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            id: outside
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => {
                if (!phone.contains(mapToItem(phone, mouse.x, mouse.y)))
                    root.close()
            }
        }

        PhoneBody {
            id: phone
            height: Math.round(Math.min((win.screen?.height ?? 1080) * 0.8, 860))
            width: Math.round(height * 0.49)
            x: win.width * root.horizontalCenterShare - width / 2
            y: win.height - win.stageHeight + win.headroom + stage.lift
            transform: Rotation {
                origin.x: phone.width / 2
                origin.y: phone.height
                angle: root.pocketRoll * stage.tilt
            }
        }
    }

    component Slot: Item {
        id: slot
        required property string name
        required property var stack
        default property Item page
        readonly property int depth: stack.indexOf(name)
        readonly property int topDepth: stack.length - 1
        property real position: depth < 0 ? 1 : depth === topDepth ? 0 : -0.3
        Behavior on position { NumberAnimation { duration: 380; easing.type: Easing.OutQuint } }
        width: parent.width
        height: parent.height
        x: width * position
        visible: position < 1 && (depth < 0 || depth >= topDepth - 1)
        z: depth < 0 ? stack.length : depth
        Component.onCompleted: page.parent = slot

        Rectangle {
            anchors.fill: parent
            z: 1
            visible: slot.position < 0
            color: "black"
            opacity: -slot.position / 0.3 * 0.12
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

                Item {
                    id: display
                    property var stack: ["chat"]
                    readonly property string current: stack[stack.length - 1]
                    readonly property real hiddenBottom: body.height * (1 - root.visibleShare) - body.bezel
                    anchors.fill: parent
                    Component.onCompleted: root.display = display

                    function focusCurrent() {
                        for (const slot of children)
                            if (slot.name === current) slot.page.focusPage()
                    }
                    function push(name) {
                        stack = stack.concat([name])
                        focusCurrent()
                    }
                    function pop() {
                        stack = stack.slice(0, -1)
                        focusCurrent()
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: glassShape
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }

                    Slot {
                        name: "chat"
                        stack: display.stack
                        Chat {
                            anchors.fill: parent
                            active: root.raised && display.current === "chat"
                            hiddenBottom: display.hiddenBottom
                            onDismissed: root.close()
                            onSettingsRequested: display.push("settings")
                        }
                    }

                    Slot {
                        name: "settings"
                        stack: display.stack
                        Settings.SettingsPage {
                            anchors.fill: parent
                            active: root.raised && display.current === "settings"
                            hiddenBottom: display.hiddenBottom
                            onBack: display.pop()
                            onOpenSchedules: display.push("schedules")
                            onOpenBackground: display.push("background")
                            onOpenName: {
                                namePage.load()
                                display.push("name")
                            }
                            onOpenCharacter: {
                                characterPage.load()
                                display.push("character")
                            }
                        }
                    }

                    Slot {
                        name: "name"
                        stack: display.stack
                        Settings.NamePage {
                            id: namePage
                            anchors.fill: parent
                            active: root.raised && display.current === "name"
                            hiddenBottom: display.hiddenBottom
                            onBack: display.pop()
                        }
                    }

                    Slot {
                        name: "background"
                        stack: display.stack
                        Settings.BackgroundPage {
                            anchors.fill: parent
                            active: root.raised && display.current === "background"
                            hiddenBottom: display.hiddenBottom
                            onBack: display.pop()
                        }
                    }

                    Slot {
                        name: "character"
                        stack: display.stack
                        Settings.CharacterPage {
                            id: characterPage
                            anchors.fill: parent
                            active: root.raised && display.current === "character"
                            hiddenBottom: display.hiddenBottom
                            onBack: display.pop()
                        }
                    }

                    Slot {
                        name: "schedules"
                        stack: display.stack
                        Settings.SchedulesPage {
                            anchors.fill: parent
                            active: root.raised && display.current === "schedules"
                            hiddenBottom: display.hiddenBottom
                            onBack: display.pop()
                        }
                    }
                }
            }
        }
    }
}
