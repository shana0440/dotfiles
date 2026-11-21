import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

PopupWindow {
    id: root

    property Item island: null
    property string picking: ""
    readonly property int shadowMargin: 16
    readonly property int gap: 8
    readonly property bool hovered: visible && panelHover.hovered

    function open() {
        picking = ""
        visible = true
    }

    function close() {
        visible = false
    }

    function togglePicker(what) {
        picking = picking === what ? "" : what
    }

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    anchor.item: island
    anchor.rect.x: island ? island.width + shadowMargin : 0
    anchor.rect.y: island ? island.height + gap - shadowMargin : 0
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Left
    grabFocus: true
    color: Theme.Colors.transparent
    implicitWidth: panel.width + shadowMargin * 2
    implicitHeight: panel.height + shadowMargin * 2

    component DevicePicker: Column {
        id: picker
        property bool input: false
        readonly property var current: input ? Services.Sound.source : Services.Sound.sink
        readonly property var choices: Services.Sound.devices(input)
        width: parent.width
        spacing: 2

        Text {
            visible: picker.choices.length === 0
            leftPadding: 10
            height: 30
            verticalAlignment: Text.AlignVCenter
            text: !Pipewire.ready ? "Connecting to PipeWire" : picker.input ? "No microphones" : "No output devices"
            color: Theme.Colors.muted
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 12
        }

        Repeater {
            model: picker.choices

            Rectangle {
                id: choice
                required property var modelData
                readonly property bool selected: picker.current === modelData
                readonly property string label: Services.Sound.label(modelData)

                width: picker.width
                height: 32
                radius: 8
                color: rowMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent

                Components.Icon {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    visible: choice.selected
                    action: "check"
                }
                Text {
                    x: 30
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 8
                    text: choice.label
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: choice.selected ? Theme.Colors.foreground : Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Sound.select(picker.input, choice.modelData)
                }
            }
        }
    }

    Rectangle {
        id: panel
        x: root.shadowMargin
        y: root.shadowMargin
        width: 340
        height: content.implicitHeight + 32
        radius: 16
        color: Theme.Colors.panel
        border.width: 1
        border.color: Theme.Colors.edge

        HoverHandler { id: panelHover }

        RectangularShadow {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            offset.y: 4
            blur: 12
            spread: -4
            color: Theme.Colors.shadow
        }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: root.close()
        }

        Column {
            id: content
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 4

            SoundLevel {
                node: Services.Sound.sink
                icon: "speaker"
                mutedIcon: "speakerMuted"
                what: "output"
                label: Services.Sound.label(node) || "No output device"
                expandable: true
                expanded: root.picking === "output"
                onExpandToggled: root.togglePicker("output")
            }
            DevicePicker {
                visible: root.picking === "output"
            }
            SoundLevel {
                node: Services.Sound.source
                icon: "microphone"
                mutedIcon: "microphoneMuted"
                what: "input"
                label: Services.Sound.label(node) || "No input device"
                expandable: true
                expanded: root.picking === "input"
                onExpandToggled: root.togglePicker("input")
            }
            DevicePicker {
                visible: root.picking === "input"
                input: true
            }

            Text {
                topPadding: 8
                bottomPadding: 4
                text: "Apps"
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 12
            }
            Text {
                visible: Services.Sound.streams.length === 0
                height: 30
                verticalAlignment: Text.AlignVCenter
                text: "No apps are playing sound"
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 12
            }
            Repeater {
                model: Services.Sound.streams

                SoundLevel {
                    required property var modelData
                    readonly property string media: modelData.properties["media.name"] ?? ""
                    node: modelData
                    icon: "audio"
                    mutedIcon: "audio"
                    iconSource: Services.Sound.appIcon(modelData)
                    what: Services.Sound.appName(modelData)
                    label: media && media.toLowerCase() !== what.toLowerCase() ? what + " · " + media : what
                }
            }
        }
    }
}
