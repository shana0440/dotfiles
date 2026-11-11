import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme" as Theme

Scope {
    id: root
    property bool opened: false
    property var items: []
    property string directory: ""
    property string message: ""
    property string currentPath: ""
    property string pendingPath: ""
    property var chosenScreen: Quickshell.screens[0] ?? null
    readonly property bool busy: library.running || setter.running

    function show() {
        if (setter.running) return
        chosenScreen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null
        message = ""
        opened = true
        query.running = true
        stage.forceActiveFocus()
    }
    function close() { if (!setter.running) opened = false }
    function move(step) {
        if (items.length && !busy)
            carousel.currentIndex = Math.max(0, Math.min(items.length - 1, carousel.currentIndex + step))
    }
    function apply() {
        if (busy || carousel.currentIndex < 0 || !items.length) return
        pendingPath = items[carousel.currentIndex].path
        message = ""
        setter.running = true
    }

    Process {
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
        onExited: library.running = true
    }
    Process {
        id: library
        command: ["wallpaper-library"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    root.items = result.items
                    root.directory = result.directory
                    const index = root.items.findIndex(i => i.path === root.currentPath)
                    carousel.currentIndex = index >= 0 ? index : 0
                    root.message = result.errors.length ? result.errors.length + " image(s) could not be loaded" : ""
                } catch (_) { root.message = "Could not read the wallpaper library" }
            }
        }
        stderr: StdioCollector { id: libraryError }
        onExited: (code) => { if (code !== 0) root.message = libraryError.text || "Could not load wallpapers" }
    }
    Process {
        id: setter
        command: ["wallpaper-set", root.pendingPath]
        stderr: StdioCollector { id: setError }
        onExited: (code) => {
            if (code === 0) {
                root.currentPath = root.pendingPath
                root.opened = false
            } else root.message = setError.text || "Wallpaper change failed"
        }
    }
    Component.onCompleted: library.running = true

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
                selected: root.items[carousel.currentIndex]?.path ?? "", current: root.currentPath, error: root.message})
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
            MouseArea { anchors.fill: parent; onClicked: root.close() }
            WheelHandler {
                onWheel: event => {
                    if (event.angleDelta.y !== 0) root.move(event.angleDelta.y > 0 ? -1 : 1)
                    else if (event.angleDelta.x !== 0) root.move(event.angleDelta.x > 0 ? -1 : 1)
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.max(1, Math.min(parent.width - 32, 1100))
                height: Math.max(1, Math.min(parent.height - 48, 620))
                color: "#ed121212"
                radius: 20
                border.color: Theme.Colors.activeWorkspace
                clip: true

                Text {
                    anchors { top: parent.top; topMargin: 24; horizontalCenter: parent.horizontalCenter }
                    text: "Wallpapers"
                    color: Theme.Colors.foreground
                    font { pixelSize: 24; bold: true }
                }
                ListView {
                    id: carousel
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 80; bottom: footer.top; bottomMargin: 16 }
                    orientation: ListView.Horizontal
                    model: root.items
                    readonly property real cardWidth: Math.max(1, Math.min(width * 0.62, height * 1.65))
                    readonly property real cardHeight: cardWidth / 1.6
                    readonly property real slotWidth: cardWidth * 0.60
                    preferredHighlightBegin: (width - slotWidth) / 2
                    preferredHighlightEnd: (width + slotWidth) / 2
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 220
                    snapMode: ListView.SnapToItem
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: !root.busy
                    cacheBuffer: Math.max(0, width)
                    delegate: Item {
                        id: slot
                        required property var modelData
                        required property int index
                        width: carousel.slotWidth
                        height: carousel.height
                        readonly property real distance: Math.abs((x + width / 2 - carousel.contentX - carousel.width / 2) / width)
                        z: 100 - distance
                        opacity: Math.max(0, 1 - distance * 0.23)
                        Rectangle {
                            anchors.centerIn: parent
                            width: carousel.cardWidth
                            height: carousel.cardHeight
                            scale: Math.max(0.5, 1 - slot.distance * 0.26)
                            color: Theme.Colors.background
                            border { width: 3; color: slot.index === carousel.currentIndex ? Theme.Colors.accent : Theme.Colors.activeWorkspace }
                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(1, -0.16, 0, carousel.cardHeight * 0.08, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }
                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: slot.modelData.thumbnail
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 900
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.busy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: carousel.currentIndex = slot.index
                                onDoubleClicked: { carousel.currentIndex = slot.index; root.apply() }
                            }
                        }
                    }
                }
                Column {
                    id: footer
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 24 }
                    spacing: 10
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.busy ? (setter.running ? "Applying wallpaper…" : "Loading thumbnails…")
                            : root.items.length ? root.items[carousel.currentIndex]?.name ?? ""
                            : "Add JPG, PNG, or WebP images to " + root.directory
                        color: Theme.Colors.foreground
                        font.pixelSize: 16
                        elide: Text.ElideMiddle
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.message || (root.items[carousel.currentIndex]?.path === root.currentPath
                            ? "Current wallpaper  ·  " : "") + "← → Browse   ·   Enter Apply to all monitors   ·   Esc Close"
                        color: root.message ? "#fca5a5" : Theme.Colors.accent
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
