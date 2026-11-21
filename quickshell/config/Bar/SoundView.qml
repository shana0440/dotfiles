import QtQuick
import Quickshell.Services.Pipewire
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    property bool active: false
    property string picking: ""

    onActiveChanged: picking = ""

    function togglePicker(what) {
        picking = picking === what ? "" : what
    }

    width: 360
    height: content.implicitHeight + 40

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

    Column {
        id: content
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 4

        Text {
            bottomPadding: 6
            text: "Sound"
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.pixelSize: 16
            font.bold: true
        }

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
