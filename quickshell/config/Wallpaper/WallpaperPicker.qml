import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../Theme" as Theme
import "../Components" as Components

Scope {
    id: root
    property bool opened: false
    property bool preparing: false
    property var items: []
    property string directory: ""
    property string message: ""
    property string currentPath: ""
    property var setters: []
    property int started: 0
    property int finishedOrder: 0
    property int selected: -1
    property int view: -1
    property bool pointing: false
    property int hovered: -1
    property var chosenScreen: Quickshell.screens[0] ?? null
    readonly property bool busy: preparing || query.running || library.running
    readonly property string targetPath: setters.length ? setters[setters.length - 1].path : currentPath

    function show() {
        for (const setter of setters) setter.closeOnReady = false
        chosenScreen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null
        message = ""
        preparing = true
        opened = true
        query.start()
        if (!colonyWarm.running) colonyWarm.running = true
    }
    function finishOpening() {
        if (!opened || !preparing || query.running || library.running) return
        const index = items.findIndex(i => i.path === targetPath)
        selected = items.length ? Math.max(0, index) : -1
        view = selected
        pointing = false
        Qt.callLater(() => {
            if (!opened || query.running || library.running) return
            preparing = false
            stage.forceActiveFocus()
        })
    }
    function close() {
        opened = false
        preparing = false
    }
    function clamp(index) {
        return Math.max(0, Math.min(items.length - 1, index))
    }
    function move(step) {
        if (!items.length || busy) return
        pointing = false
        selected = clamp(selected + step)
        view = selected
    }
    function point() {
        pointing = true
        if (hovered >= 0) selected = hovered
    }
    function hover(index, inside) {
        if (inside) hovered = index
        else if (hovered === index) hovered = -1
        if (inside && pointing) selected = index
    }
    function scroll(step) {
        if (items.length && !busy) view = clamp(view + step)
    }
    function apply() {
        if (busy || selected < 0 || !items.length) return
        const path = items[selected].path
        message = ""
        if (path === targetPath) { close(); return }
        const setter = setterComponent.createObject(root, { path: path, order: ++started })
        setters = setters.concat([setter])
        setter.running = true
    }
    function setterExited(setter, code, error) {
        setters = setters.filter(s => s !== setter)
        if (code === 0) {
            if (setter.order > finishedOrder) { finishedOrder = setter.order; currentPath = setter.path }
            if (setter.closeOnReady) close()
        } else {
            message = error || "Wallpaper change failed"
            if (!setters.length) {
                opened = true
                Qt.callLater(() => stage.forceActiveFocus())
            }
        }
        setter.destroy()
    }
    function label(path) {
        if (path === targetPath) return setters.length ? "Applying" : "Current"
        return ""
    }

    component Helper: Process {
        property bool launched: false
        signal failedToStart()
        function start() {
            if (running) return
            launched = false
            running = true
        }
        onStarted: launched = true
        onRunningChanged: if (!running && !launched) failedToStart()
    }
    Helper {
        id: query
        command: ["awww", "query", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentPath = ""
                try {
                    const outputs = JSON.parse(text)[""] ?? []
                    const output = outputs.find(o => o.name === root.chosenScreen?.name) ?? outputs[0]
                    root.currentPath = output?.displaying?.image ?? ""
                } catch (_) {}
            }
        }
        onExited: library.start()
        onFailedToStart: {
            root.message = "Could not run awww to find the current wallpaper"
            library.start()
        }
    }
    Helper {
        id: library
        command: ["wallpaper-library"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    root.selected = -1
                    root.items = result.items
                    root.directory = result.directory
                    if (result.errors.length) root.message = result.errors.length + " image(s) could not be loaded"
                } catch (_) { root.message = "Could not read the wallpaper library" }
            }
        }
        stderr: StdioCollector { id: libraryError }
        onExited: (code) => {
            if (code !== 0) root.message = libraryError.text || "Could not load wallpapers"
            Qt.callLater(root.finishOpening)
        }
        onFailedToStart: {
            root.message = "Could not run wallpaper-library"
            Qt.callLater(root.finishOpening)
        }
    }
    Process {
        id: colonyWarm
        command: ["wallpaper-colonies", "warm"]
    }
    Component {
        id: setterComponent
        Process {
            id: setter
            required property string path
            required property int order
            property bool closeOnReady: true
            command: ["wallpaper-set", path]
            stdout: SplitParser {
                onRead: data => {
                    if (data === "transition-ready" && setter.closeOnReady) {
                        setter.closeOnReady = false
                        root.close()
                    }
                }
            }
            stderr: StdioCollector { id: setError }
            onExited: code => root.setterExited(setter, code, setError.text)
        }
    }
    Component.onCompleted: library.start()

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { if (root.opened) root.close(); else root.show() }
        function open(): void { root.show() }
        function close(): void { root.close() }
        function next(): void { root.move(1) }
        function previous(): void { root.move(-1) }
        function apply(): void { if (root.opened) root.apply() }
        function state(): string {
            return JSON.stringify({open: root.opened, busy: root.busy, count: root.items.length,
                selected: root.items[root.selected]?.path ?? "", current: root.currentPath,
                applying: root.setters.map(s => s.path), error: root.message})
        }
    }

    PanelWindow {
        id: win
        screen: root.chosenScreen
        visible: root.opened || stage.opacity > 0
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-wallpaper"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            opacity: root.opened ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Keys.onEscapePressed: root.close()
            Keys.onLeftPressed: root.move(-1)
            Keys.onRightPressed: root.move(1)
            Keys.onReturnPressed: root.apply()
            Keys.onEnterPressed: root.apply()

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#33000000" }
                    GradientStop { position: 1; color: "#cc000000" }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root.close() }
            HoverHandler {
                id: edge
                readonly property real zone: stage.width * 0.15
                readonly property real pointerX: point.position.x
                readonly property bool inside: hovered && point.position.y < bar.y
                readonly property int direction: !inside ? 0 : pointerX < zone ? -1 : pointerX > stage.width - zone ? 1 : 0
                readonly property int urgency: direction < 0 ? Math.ceil((zone - pointerX) / zone * 3)
                    : direction > 0 ? Math.ceil((pointerX - stage.width + zone) / zone * 3) : 0
                property point last
                onHoveredChanged: last = point.scenePosition
                onPointChanged: {
                    const now = point.scenePosition
                    if (!hovered || (now.x === last.x && now.y === last.y)) return
                    last = now
                    root.point()
                }
            }
            Timer {
                running: root.opened && !root.busy && root.pointing && edge.direction !== 0
                interval: [420, 420, 260, 140][edge.urgency]
                repeat: true
                triggeredOnStart: true
                onTriggered: root.scroll(edge.direction)
            }

            Item {
                id: hand
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: bar.top; bottomMargin: 24 }
                opacity: root.preparing ? 0 : 1
                readonly property real cardHeight: Math.max(1, Math.min(height * 0.5, 440))
                readonly property real cardWidth: cardHeight * 0.72
                readonly property real step: 0.6
                readonly property real reach: Math.max(1, Math.ceil(width / 2 / (cardWidth * step)) + 1)
                property real position: root.view
                Behavior on position {
                    enabled: !root.preparing
                    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: root.items
                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property real offset: index - hand.position
                        readonly property real distance: Math.abs(offset)
                        readonly property real spread: offset * hand.step
                        readonly property bool chosen: index === root.selected
                        readonly property bool current: modelData.path === root.targetPath
                        property real pick: chosen ? 1 : 0
                        Behavior on pick { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        visible: distance < hand.reach + 1
                        width: hand.cardWidth
                        height: hand.cardHeight
                        x: hand.width / 2 - width / 2 + spread * hand.cardWidth
                        y: hand.height - height * 1.12 + spread * spread * hand.cardHeight * 0.035
                            - pick * hand.cardHeight * 0.07
                        z: chosen ? root.items.length : root.items.length - 1 - index
                        rotation: spread * 7
                        transformOrigin: Item.Bottom
                        scale: 0.94 + pick * 0.1
                        opacity: Math.max(0, Math.min(1, hand.reach + 0.5 - distance))

                        RectangularShadow {
                            anchors.fill: face
                            radius: face.radius
                            offset.y: 10
                            blur: 32
                            spread: -6
                            color: "#99000000"
                        }
                        Rectangle {
                            id: face
                            anchors.fill: parent
                            radius: 22
                            color: Theme.Colors.solidSurface
                            border.width: card.chosen ? 2 : 1
                            border.color: card.chosen ? Qt.alpha(Theme.Colors.foreground, 0.7) : Theme.Colors.edge

                            ClippingRectangle {
                                id: art
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                height: parent.height - 8 - caption.height
                                radius: 15
                                color: Theme.Colors.background
                                Image {
                                    anchors.fill: parent
                                    source: card.visible ? card.modelData.thumbnail : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.height: 600
                                }
                            }
                            Rectangle {
                                anchors { top: parent.top; right: parent.right; margins: 18 }
                                visible: card.current
                                width: 30; height: 30; radius: 15
                                color: Theme.Colors.info
                                border { width: 2; color: Theme.Colors.foreground }
                                Components.Icon {
                                    anchors.centerIn: parent
                                    width: 16; height: 16
                                    action: "check"
                                    iconColor: Theme.Colors.foreground
                                }
                            }
                            Item {
                                id: caption
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: 50
                                Text {
                                    anchors { left: parent.left; right: number.left; leftMargin: 18; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: card.modelData.name.replace(/\.[^.]+$/, "")
                                    color: Theme.Colors.foreground
                                    font { family: Theme.Fonts.family; weight: Theme.Fonts.weight; pixelSize: 16 }
                                    elide: Text.ElideRight
                                }
                                Text {
                                    id: number
                                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                                    text: String(card.index + 1).padStart(2, "0")
                                    color: Theme.Colors.muted
                                    font { family: Theme.Fonts.family; weight: Theme.Fonts.weight; pixelSize: 14 }
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "#000000"
                                opacity: Math.min(1, card.distance) * 0.35 * (1 - card.pick)
                            }
                        }
                        MouseArea {
                            id: pointer
                            anchors.fill: parent
                            anchors.bottomMargin: -card.pick * hand.cardHeight * 0.07 / card.scale
                            enabled: !root.busy
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: root.hover(card.index, containsMouse)
                            onClicked: { root.selected = card.index; root.apply() }
                        }
                    }
                }
            }

            Components.Surface {
                id: bar
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 32 }
                width: Math.min(parent.width - 48, barRow.implicitWidth + 24)
                height: 52
                radius: 26
                color: Theme.Colors.panel
                border.color: Theme.Colors.ring
                MouseArea { anchors.fill: parent }

                Row {
                    id: barRow
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 10

                    Components.IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "back"
                        iconSize: 18
                        radius: 18
                        enabled: !root.busy && root.selected > 0
                        onClicked: root.move(-1)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.items.length ? (root.selected + 1) + " / " + root.items.length : "0 / 0"
                        color: Theme.Colors.foreground
                        font { family: Theme.Fonts.family; weight: Theme.Fonts.weight; pixelSize: 15; features: { "tnum": 1 } }
                    }
                    Components.IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "forward"
                        iconSize: 18
                        radius: 18
                        enabled: !root.busy && root.selected < root.items.length - 1
                        onClicked: root.move(1)
                    }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 22; color: Theme.Colors.ring }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, stage.width - 360)
                        leftPadding: 6
                        rightPadding: 6
                        text: {
                            if (root.message) return root.message
                            if (root.busy) return "Loading thumbnails…"
                            if (!root.items.length) return "Add JPG, PNG, or WebP images to " + root.directory
                            const status = root.label(root.items[root.selected]?.path ?? "")
                            return (status ? status + "   ·   " : "") + "← → Browse   ·   Enter Apply to all monitors   ·   Esc Close"
                        }
                        color: root.message ? Theme.Colors.error : Theme.Colors.muted
                        font { family: Theme.Fonts.family; weight: Theme.Fonts.weight; pixelSize: 14 }
                        elide: Text.ElideMiddle
                    }
                    Components.IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        iconSize: 18
                        radius: 18
                        highlighted: true
                        onClicked: root.close()
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                property real pending: 0
                onWheel: wheel => {
                    pending += wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                    if (Math.abs(pending) < 120) return
                    root.move(pending > 0 ? -1 : 1)
                    pending = 0
                }
            }
        }
    }
}
