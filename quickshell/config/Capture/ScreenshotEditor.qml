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
    property var draft: null
    property string message: ""
    readonly property var tools: [
        { name: "pen", icon: "pen", label: "Pen" }
    ]
    readonly property var colors: [Theme.Colors.error, Theme.Colors.warning, Theme.Colors.success, Theme.Colors.info, "#ffffff", "#000000"]
    readonly property var widths: [2, 4, 8]

    function edit(file) {
        chosenScreen = Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        operations = []
        draft = null
        message = ""
        path = file
    }

    function close() {
        path = ""
        operations = []
        draft = null
    }

    function commit(operation) {
        operations = operations.concat([operation])
    }

    function begin(point) {
        draft = { kind: "pen", color: String(color), width: strokeWidth / viewport.fit, points: [point, Qt.point(point.x + 0.01, point.y)] }
    }

    function extend(point) {
        if (draft)
            draft = Object.assign({}, draft, { points: draft.points.concat([point]) })
    }

    function finish() {
        if (draft)
            commit(draft)
        draft = null
    }

    function save() {
        if (!editing || image.status !== Image.Ready)
            return
        const file = path
        page.grabToImage(result => {
            if (!result.saveToFile(file)) {
                root.message = "Could not save " + file
                return
            }
            clipboard.exec(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", file])
            root.close()
        }, Qt.size(page.width, page.height))
    }

    function state() {
        return {
            editing, path, tool, color: String(color), width: strokeWidth,
            operations: operations.map(operation => operation.kind), message
        }
    }

    Process { id: clipboard }

    IpcHandler {
        target: "screenshotEditor"
        function open(path: string): void { root.edit(path) }
        function close(): void { root.close() }
        function save(): void { root.save() }
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
                width: image.implicitWidth
                height: image.implicitHeight
                x: (viewport.width - width * scale) / 2
                y: (viewport.height - height * scale) / 2
                scale: viewport.fit
                transformOrigin: Item.TopLeft
                clip: true

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
                    anchors.fill: parent
                    operation: root.draft
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    onPressed: mouse => root.begin(Qt.point(mouse.x, mouse.y))
                    onPositionChanged: mouse => root.extend(Qt.point(mouse.x, mouse.y))
                    onReleased: root.finish()
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

        Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: root.editing; onActivated: root.close() }
        Shortcut { sequence: "Ctrl+S"; context: Qt.ApplicationShortcut; enabled: root.editing; onActivated: root.save() }
    }

    component Separator: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 28
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        color: Theme.Colors.track
    }
}
