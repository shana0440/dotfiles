import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../Theme" as Theme
import "../Components" as Components

Scope {
    id: root

    property string path: ""
    readonly property bool editing: path.length > 0
    property var chosenScreen: null
    property string tool: "pen"
    property color color: Theme.Colors.error
    property int strokeWidth: 4
    property var operations: []
    property var undone: []
    property var draft: null
    property var typing: null
    readonly property rect crop: {
        for (let index = operations.length - 1; index >= 0; index--) {
            if (operations[index].kind === "crop")
                return operations[index].rect
        }
        return Qt.rect(0, 0, image.implicitWidth, image.implicitHeight)
    }
    property string message: ""
    readonly property var tools: [
        { name: "crop", icon: "crop", label: "Crop" },
        { name: "rect", icon: "rectangle", label: "Rectangle" },
        { name: "ellipse", icon: "ellipse", label: "Ellipse" },
        { name: "pen", icon: "pen", label: "Pen" },
        { name: "text", icon: "text", label: "Text" }
    ]
    readonly property var colors: [Theme.Colors.error, Theme.Colors.warning, Theme.Colors.success, Theme.Colors.info, "#ffffff", "#000000"]
    readonly property var widths: [2, 4, 8]

    function edit(file) {
        chosenScreen = Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        operations = []
        undone = []
        draft = null
        typing = null
        message = ""
        path = file
    }

    function close() {
        path = ""
        operations = []
        undone = []
        draft = null
        typing = null
    }

    onToolChanged: finishText()

    function finishText() {
        if (typing && textInput.text.trim().length > 0)
            commit(Object.assign({}, typing, { text: textInput.text }))
        typing = null
    }

    function back() {
        if (typing)
            typing = null
        else
            close()
    }

    function commit(operation) {
        operations = operations.concat([operation])
        undone = []
    }

    function undo() {
        typing = null
        if (operations.length === 0)
            return
        undone = undone.concat([operations[operations.length - 1]])
        operations = operations.slice(0, -1)
    }

    function redo() {
        typing = null
        if (undone.length === 0)
            return
        operations = operations.concat([undone[undone.length - 1]])
        undone = undone.slice(0, -1)
    }

    function begin(point) {
        finishText()
        if (tool === "text") {
            typing = { kind: "text", at: point, color: String(color), size: (12 + strokeWidth * 3) / viewport.fit }
            textInput.text = ""
            textInput.forceActiveFocus()
            return
        }
        const style = { kind: tool, color: String(color), stroke: strokeWidth / viewport.fit }
        draft = Object.assign(style, tool === "pen"
            ? { points: [point, Qt.point(point.x + 0.01, point.y)] }
            : { from: point, to: point })
    }

    function extend(point) {
        if (draft)
            draft = Object.assign({}, draft, draft.kind === "pen" ? { points: draft.points.concat([point]) } : { to: point })
    }

    function finish() {
        if (draft?.kind === "crop")
            cropTo(draftAnnotation.box)
        else if (draft && (draft.kind === "pen" || (draft.from.x !== draft.to.x && draft.from.y !== draft.to.y)))
            commit(draft)
        draft = null
    }

    function cropTo(box) {
        const left = Math.round(Math.max(box.x, crop.x))
        const top = Math.round(Math.max(box.y, crop.y))
        const right = Math.round(Math.min(box.x + box.width, crop.x + crop.width))
        const bottom = Math.round(Math.min(box.y + box.height, crop.y + crop.height))
        if (right - left >= 4 && bottom - top >= 4)
            commit({ kind: "crop", rect: Qt.rect(left, top, right - left, bottom - top) })
    }

    function save() {
        if (!editing || image.status !== Image.Ready)
            return
        finishText()
        const file = path
        page.grabToImage(result => {
            if (!result.saveToFile(file)) {
                root.message = "Could not save " + file
                return
            }
            clipboard.exec(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", file])
            Quickshell.execDetached(["screen-capture-notify", "screenshot", file])
            root.close()
        }, Qt.size(page.width, page.height))
    }

    function state() {
        return {
            editing, path, tool, color: String(color), width: strokeWidth, typing: typing !== null,
            crop: { x: crop.x, y: crop.y, width: crop.width, height: crop.height },
            operations: operations.map(operation => operation.kind), undone: undone.length, message
        }
    }

    Process { id: clipboard }

    IpcHandler {
        target: "screenshotEditor"
        function open(path: string): void { root.edit(path) }
        function close(): void { root.close() }
        function save(): void { root.save() }
        function undo(): void { root.undo() }
        function redo(): void { root.redo() }
        function tool(name: string): void { if (root.tools.some(tool => tool.name === name)) root.tool = name }
        function color(value: string): void { root.color = value }
        function width(value: int): void { root.strokeWidth = value }
        function state(): string { return JSON.stringify(root.state()) }
    }

    PanelWindow {
        visible: root.editing
        screen: root.chosenScreen
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        color: Qt.alpha(Theme.Colors.background, 0.88)
        WlrLayershell.namespace: "quickshell-screenshot-editor"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Item {
            id: viewport
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: toolbar.top
            anchors.margins: 32
            readonly property real fit: page.width > 0 && page.height > 0
                ? Math.min(1, width / page.width, height / page.height) : 1

            Item {
                id: page
                width: root.crop.width
                height: root.crop.height
                x: (viewport.width - width * scale) / 2
                y: (viewport.height - height * scale) / 2
                scale: viewport.fit
                transformOrigin: Item.TopLeft
                clip: true

                Item {
                    id: canvas
                    x: -root.crop.x
                    y: -root.crop.y
                    width: image.implicitWidth
                    height: image.implicitHeight

                    Image {
                        id: image
                        source: root.editing ? "file://" + root.path.split("/").map(encodeURIComponent).join("/") : ""
                        cache: false
                        smooth: true
                        mipmap: true
                    }

                    Repeater {
                        model: root.operations
                        Annotation {
                            required property var modelData
                            anchors.fill: parent
                            operation: modelData
                        }
                    }

                    Annotation {
                        id: draftAnnotation
                        anchors.fill: parent
                        operation: root.draft
                    }

                    Item {
                        anchors.fill: parent
                        visible: root.draft?.kind === "crop"
                        readonly property rect box: draftAnnotation.box
                        readonly property color dim: Qt.alpha(Theme.Colors.background, 0.6)

                        Rectangle { x: 0; y: 0; width: parent.width; height: parent.box.y; color: parent.dim }
                        Rectangle { x: 0; y: parent.box.y + parent.box.height; width: parent.width; height: parent.height - y; color: parent.dim }
                        Rectangle { x: 0; y: parent.box.y; width: parent.box.x; height: parent.box.height; color: parent.dim }
                        Rectangle { x: parent.box.x + parent.box.width; y: parent.box.y; width: parent.width - x; height: parent.box.height; color: parent.dim }
                        Rectangle {
                            x: parent.box.x
                            y: parent.box.y
                            width: parent.box.width
                            height: parent.box.height
                            color: Theme.Colors.transparent
                            border.width: 1 / viewport.fit
                            border.color: Theme.Colors.foreground
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                    onPressed: mouse => root.begin(Qt.point(mouse.x + root.crop.x, mouse.y + root.crop.y))
                    onPositionChanged: mouse => root.extend(Qt.point(mouse.x + root.crop.x, mouse.y + root.crop.y))
                    onReleased: root.finish()
                }

                TextInput {
                    id: textInput
                    visible: root.typing !== null
                    x: (root.typing?.at.x ?? 0) - root.crop.x
                    y: (root.typing?.at.y ?? 0) - root.crop.y
                    color: root.typing?.color ?? "transparent"
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: root.typing?.size ?? 12
                    cursorDelegate: Rectangle {
                        width: 2 / viewport.fit
                        color: textInput.color
                    }
                    Keys.onReturnPressed: root.finishText()
                    Keys.onEnterPressed: root.finishText()
                }
            }

            Text {
                anchors.centerIn: parent
                visible: image.status === Image.Error || root.message.length > 0
                text: root.message || "Could not open " + root.path
                color: Theme.Colors.foreground
                font.family: Theme.Fonts.family
                font.pixelSize: 14
            }
        }

        Components.Surface {
            id: toolbar
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 32
            width: bar.implicitWidth + 16
            height: bar.implicitHeight + 16
            radius: 12

            RowLayout {
                id: bar
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: root.tools
                    Components.IconButton {
                        required property var modelData
                        implicitWidth: 40
                        implicitHeight: 40
                        icon: modelData.icon
                        tooltip: modelData.label
                        highlighted: root.tool === modelData.name
                        onClicked: root.tool = modelData.name
                    }
                }

                Separator {}

                Components.IconButton {
                    implicitWidth: 40
                    implicitHeight: 40
                    icon: "undo"
                    tooltip: "Undo · Ctrl+Z"
                    enabled: root.operations.length > 0
                    onClicked: root.undo()
                }

                Components.IconButton {
                    implicitWidth: 40
                    implicitHeight: 40
                    icon: "redo"
                    tooltip: "Redo · Ctrl+Shift+Z"
                    enabled: root.undone.length > 0
                    onClicked: root.redo()
                }

                Separator {}

                Repeater {
                    model: root.colors
                    Rectangle {
                        id: swatch
                        required property color modelData
                        readonly property bool chosen: Qt.colorEqual(root.color, modelData)
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: chosen || swatchMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent
                        Accessible.role: Accessible.Button
                        Accessible.name: "Color " + modelData

                        Rectangle {
                            anchors.centerIn: parent
                            width: swatch.chosen ? 18 : 16
                            height: width
                            radius: width / 2
                            color: swatch.modelData
                            border.width: 1
                            border.color: Theme.Colors.edge
                        }

                        MouseArea {
                            id: swatchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.color = swatch.modelData
                        }
                    }
                }

                Separator {}

                Repeater {
                    model: root.widths
                    Rectangle {
                        id: weight
                        required property int modelData
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 40
                        radius: 8
                        color: root.strokeWidth === modelData || weightMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent
                        Accessible.role: Accessible.Button
                        Accessible.name: "Width " + modelData

                        Rectangle {
                            anchors.centerIn: parent
                            width: weight.modelData + 4
                            height: width
                            radius: width / 2
                            color: Theme.Colors.foreground
                            opacity: root.strokeWidth === weight.modelData ? 1 : 0.6
                        }

                        MouseArea {
                            id: weightMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.strokeWidth = weight.modelData
                        }
                    }
                }

                Separator {}

                Components.IconButton {
                    implicitWidth: 40
                    implicitHeight: 40
                    icon: "close"
                    tooltip: "Discard · Esc"
                    onClicked: root.close()
                }

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 40
                    radius: 8
                    color: Theme.Colors.foreground
                    opacity: saveMouse.pressed ? 0.75 : saveMouse.containsMouse ? 0.88 : 1
                    Accessible.role: Accessible.Button
                    Accessible.name: "Save"

                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        color: Theme.Colors.background
                        font.family: Theme.Fonts.family
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.save()
                    }
                }
            }
        }

        Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: root.editing; onActivated: root.back() }
        Shortcut { sequence: "Ctrl+S"; context: Qt.ApplicationShortcut; enabled: root.editing; onActivated: root.save() }
        Shortcut { sequence: "Ctrl+Z"; context: Qt.ApplicationShortcut; enabled: root.editing; onActivated: root.undo() }
        Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; context: Qt.ApplicationShortcut; enabled: root.editing; onActivated: root.redo() }
    }

    component Separator: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 28
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        color: Theme.Colors.track
    }
}
