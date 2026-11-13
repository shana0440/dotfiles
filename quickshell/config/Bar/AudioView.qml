import QtQuick
import Quickshell.Services.Pipewire
import "../Theme" as Theme
import "../Components" as Components

// The dashboard's audio tab: volume and device for output, then for the microphone.
Item {
    id: root

    property int maximumHeight: 560

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    implicitWidth: 480
    implicitHeight: Math.min(maximumHeight, content.implicitHeight + 40)

    // Volume and mute are only live on bound nodes.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => node)
    }

    function devices(input) {
        return Pipewire.nodes.values.filter(node => node.audio && node.isSink !== input && !node.isStream)
    }

    function labelOf(node) {
        return node ? node.description || node.nickname || node.name : ""
    }

    function select(input, node) {
        if (input)
            Pipewire.preferredDefaultAudioSource = node
        else
            Pipewire.preferredDefaultAudioSink = node
    }

    // Volume and mute for one node; scroll nudges by 5%.
    component Level: Item {
        id: level
        property var node: null
        property string icon: ""
        property string mutedIcon: ""
        property string what: ""
        readonly property var audio: node?.audio ?? null
        readonly property bool muted: audio?.muted ?? false
        readonly property real volume: audio?.volume ?? 0

        function setVolume(value) {
            if (!audio)
                return
            audio.volume = Math.max(0, Math.min(1, value))
            audio.muted = false
        }

        width: parent.width
        height: 32
        enabled: audio !== null

        Components.IconButton {
            id: mute
            x: -6
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            iconSize: 16
            icon: level.muted ? level.mutedIcon : level.icon
            iconColor: level.muted ? Theme.Colors.muted : Theme.Colors.foreground
            tooltip: level.muted ? "Unmute " + level.what : "Mute " + level.what
            onClicked: level.audio.muted = !level.audio.muted
        }

        Item {
            id: slider
            anchors.left: mute.right
            anchors.leftMargin: 6
            anchors.right: percent.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 24

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Theme.Colors.track

                Rectangle {
                    width: track.width * Math.max(0, Math.min(1, level.volume))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.Colors.foreground
                    opacity: level.muted ? 0.35 : 1
                }
            }
            Rectangle {
                x: track.width * Math.max(0, Math.min(1, level.volume)) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: drag.pressed ? 16 : 14
                height: width
                radius: width / 2
                color: Theme.Colors.foreground
                visible: level.enabled && !level.muted
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => level.setVolume(mouse.x / width)
                onPositionChanged: mouse => {
                    if (pressed)
                        level.setVolume(mouse.x / width)
                }
                onWheel: wheel => level.setVolume(level.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }

        Text {
            id: percent
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            text: level.audio ? (level.muted ? "Muted" : Math.round(level.volume * 100) + "%") : "—"
            color: level.muted ? Theme.Colors.muted : Theme.Colors.foreground
            font.family: level.muted ? Theme.Fonts.family : Theme.Fonts.mono
            font.weight: level.muted ? Theme.Fonts.weight : Font.Normal
            font.pixelSize: level.muted ? 12 : 13
        }
    }

    component DeviceCard: Rectangle {
        id: card
        property string title: ""
        property bool input: false
        property var current: null
        property string icon: ""
        property string mutedIcon: ""
        readonly property var choices: root.devices(input)

        width: content.width
        height: cardContent.implicitHeight + 32
        radius: 12
        color: Theme.Colors.surface

        Column {
            id: cardContent
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 12

            Text {
                text: card.title
                color: Theme.Colors.foreground
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 15
            }

            Level {
                node: card.current
                icon: card.icon
                mutedIcon: card.mutedIcon
                what: card.input ? "microphone" : "output"
            }

            Column {
                width: parent.width
                spacing: 2

                Text {
                    visible: card.choices.length === 0
                    leftPadding: 4
                    text: !Pipewire.ready ? "Connecting to PipeWire" : card.input ? "No microphones" : "No output devices"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }

                Repeater {
                    model: card.choices

                    Rectangle {
                        id: choice
                        required property var modelData
                        readonly property bool selected: card.current === modelData
                        readonly property string label: root.labelOf(modelData)

                        width: parent.width
                        height: 36
                        radius: 8
                        color: rowMouse.containsMouse || activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
                        activeFocusOnTab: true
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: label
                        Accessible.checked: selected
                        Keys.onReturnPressed: root.select(card.input, modelData)
                        Keys.onSpacePressed: root.select(card.input, modelData)

                        Components.Icon {
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            visible: choice.selected
                            action: "check"
                        }
                        Text {
                            x: 28
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 8
                            text: choice.label
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: choice.selected ? Theme.Colors.foreground : Theme.Colors.muted
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.select(card.input, choice.modelData)
                        }
                        Components.Tooltip {
                            text: choice.label
                            shown: rowMouse.containsMouse && choice.label.length > 40
                        }
                    }
                }
            }
        }
    }

    Flickable {
        x: 20
        y: 20
        width: parent.width - 40
        height: parent.height - 40
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            width: parent.width
            spacing: 16

            Item {
                width: parent.width
                height: 32

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Audio"
                        color: Theme.Colors.foreground
                        font.family: Theme.Fonts.family
                        font.pixelSize: 16
                        font.bold: true
                    }
                    Text {
                        width: content.width
                        text: Pipewire.ready ? "Playing through " + (root.labelOf(root.sink) || "nothing") : "Connecting to PipeWire"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Colors.muted
                        font.family: Theme.Fonts.family
                        font.weight: Theme.Fonts.weight
                        font.pixelSize: 11
                    }
                }
            }

            DeviceCard {
                title: "Output"
                current: root.sink
                icon: "speaker"
                mutedIcon: "speakerMuted"
            }
            DeviceCard {
                title: "Input"
                input: true
                current: root.source
                icon: "microphone"
                mutedIcon: "microphoneMuted"
            }
        }
    }
}
