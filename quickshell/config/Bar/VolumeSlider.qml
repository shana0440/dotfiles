import QtQuick
import Quickshell.Services.Pipewire
import "../Theme" as Theme

Item {
    id: root

    signal adjusted()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio ?? null
    readonly property bool interacting: sliderMouse.pressed || muteMouse.pressed
    property bool feedbackEnabled: false

    PwObjectTracker {
        id: volumeSubscription
        objects: root.sink ? [root.sink] : []
    }

    // PipeWire emits initial volume values when binding a device; suppress startup feedback.
    onAudioChanged: {
        feedbackEnabled = false
        deviceSettleTimer.restart()
    }
    Component.onCompleted: deviceSettleTimer.restart()

    Timer {
        id: deviceSettleTimer
        interval: 300
        onTriggered: root.feedbackEnabled = true
    }

    Connections {
        target: root.audio

        function onVolumesChanged() {
            if (root.feedbackEnabled)
                root.adjusted()
        }

        function onMutedChanged() {
            if (root.feedbackEnabled)
                root.adjusted()
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Text {
            width: 36
            height: 32
            text: root.audio?.muted ? "Mute" : "Vol"
            color: Theme.Colors.foreground
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                id: muteMouse
                anchors.fill: parent
                enabled: root.audio !== null
                cursorShape: Qt.PointingHandCursor
                onClicked: root.audio.muted = !root.audio.muted
            }
        }

        Item {
            width: 150
            height: 32

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Theme.Colors.track

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.audio?.volume ?? 0))
                    height: parent.height
                    radius: 2
                    color: Theme.Colors.foreground
                    opacity: root.audio?.muted ? 0.35 : 1
                }
            }

            MouseArea {
                id: sliderMouse
                anchors.fill: parent
                enabled: root.audio !== null
                cursorShape: Qt.PointingHandCursor

                function setVolume(x) {
                    root.audio.volume = Math.max(0, Math.min(1, x / width))
                    root.audio.muted = false
                    root.adjusted()
                }

                onPressed: mouse => setVolume(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        setVolume(mouse.x)
                }
            }
        }

        Text {
            width: 38
            height: 32
            text: Math.round((root.audio?.volume ?? 0) * 100) + "%"
            color: Theme.Colors.foreground
            font.pixelSize: 12
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
