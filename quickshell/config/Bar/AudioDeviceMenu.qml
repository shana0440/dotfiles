import QtQuick
import Quickshell.Services.Pipewire
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root

    property real maximumHeight: 720
    property bool input: false
    readonly property var devices: Pipewire.nodes.values.filter(node => node.audio && node.isSink !== input && !node.isStream)
    readonly property var currentDevice: input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
    signal closeRequested()

    implicitWidth: 380
    implicitHeight: Math.min(78 + Math.max(40, devices.length * 48), maximumHeight)

    function selectDevice(device) {
        if (input)
            Pipewire.preferredDefaultAudioSource = device
        else
            Pipewire.preferredDefaultAudioSink = device
    }

    // Keep clicks in the menu from reaching the outside-dismissal surface.
    MouseArea { anchors.fill: parent }

    Row {
        x: 16
        y: 12
        width: parent.width - 32
        height: 32
        Text {
            width: parent.width - 32
            height: 32
            text: root.input ? "Voice input · microphone" : "Audio output"
            color: Theme.Colors.foreground
            font.pixelSize: 16
            font.bold: true
            verticalAlignment: Text.AlignVCenter
        }
        Components.IconButton {
            width: 32
            height: 32
            icon: "close"
            tooltip: "Close device selector (Esc)"
            onClicked: root.closeRequested()
        }
    }

    Flickable {
        id: viewport
        x: 16
        y: 56
        width: parent.width - 32
        height: parent.height - y - 16
        contentHeight: choices.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: choices
            width: viewport.width
            spacing: 4

            Text {
                visible: root.devices.length === 0
                width: parent.width
                height: 40
                text: Pipewire.ready ? (root.input ? "No microphone devices available" : "No audio output devices available") : "Connecting to PipeWire…"
                color: Theme.Colors.foreground
                opacity: 0.65
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: root.devices
                delegate: Rectangle {
                    id: choice
                    required property var modelData
                    readonly property bool selected: root.currentDevice === modelData
                    readonly property string label: modelData.description || modelData.nickname || modelData.name
                    width: choices.width
                    height: 44
                    radius: 8
                    color: selected || mouse.containsMouse || activeFocus ? Theme.Colors.activeWorkspace : Theme.Colors.transparent
                    activeFocusOnTab: true
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: label
                    Accessible.checked: selected
                    Keys.onReturnPressed: root.selectDevice(modelData)
                    Keys.onSpacePressed: root.selectDevice(modelData)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 44
                        text: choice.label
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Colors.foreground
                        font.pixelSize: 13
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: choice.selected
                        text: "✓"
                        color: Theme.Colors.accent
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectDevice(choice.modelData)
                    }
                    Components.Tooltip {
                        text: choice.label
                        shown: mouse.containsMouse
                    }
                }
            }
        }
    }
}
