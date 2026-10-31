import QtQuick
import Quickshell.Widgets
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    property bool active: false
    signal closeRequested()
    readonly property var player: Services.Media.player
    readonly property real duration: player?.lengthSupported ? Math.max(0, player.length) : 0
    readonly property real position: player?.positionSupported ? Math.max(0, player.position) : 0
    readonly property bool seekable: (player?.canSeek ?? false)
        && (player?.positionSupported ?? false) && duration > 0
    property real previewPosition: 0

    implicitWidth: 380
    implicitHeight: content.implicitHeight + 32

    function formatTime(seconds) {
        const value = Math.max(0, Math.floor(seconds))
        const minutes = Math.floor(value / 60)
        return minutes + ":" + String(value % 60).padStart(2, "0")
    }

    // MPRIS position needs explicit refreshes to advance the seek bar during playback.
    Timer {
        id: positionRefresh
        interval: 250
        repeat: true
        running: root.active && (root.player?.isPlaying ?? false)
        onTriggered: root.player.positionChanged()
    }

    Column {
        id: content
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 12

        Row {
            width: parent.width
            height: 72
            spacing: 12

            ClippingRectangle {
                width: 72
                height: 72
                radius: 8
                color: Theme.Colors.activeWorkspace

                Image {
                    id: artwork
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 144
                    sourceSize.height: 144
                }

                Components.Icon {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    action: "audio"
                    iconColor: Theme.Colors.accent
                    visible: artwork.status !== Image.Ready
                }
            }

            Column {
                width: parent.width - 72 - 28 - 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    width: parent.width
                    text: Services.Media.title
                    color: Theme.Colors.foreground
                    font.pixelSize: 14
                    font.bold: true
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: Services.Media.artist
                    color: Theme.Colors.foreground
                    opacity: 0.75
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.player?.trackAlbum ?? ""
                    visible: text.length > 0
                    color: Theme.Colors.foreground
                    opacity: 0.5
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Components.IconButton {
                width: 28
                height: 28
                icon: "close"
                tooltip: "Close media"
                onClicked: root.closeRequested()
            }
        }

        Row {
            id: spectrum
            width: parent.width
            height: 40
            spacing: 3

            Repeater {
                model: Services.Cava.barCount

                Rectangle {
                    required property int index

                    anchors.verticalCenter: parent.verticalCenter
                    width: (spectrum.width - (Services.Cava.barCount - 1) * spectrum.spacing) / Services.Cava.barCount
                    height: Math.max(3, spectrum.height * (Services.Cava.bars[index] ?? 0))
                    radius: width / 2
                    color: Theme.Colors.accent
                    opacity: 0.8

                    Behavior on height {
                        SmoothedAnimation { velocity: 240 }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 32

            Rectangle {
                y: 5
                width: parent.width
                height: 4
                radius: 2
                color: Theme.Colors.activeWorkspace

                Rectangle {
                    width: root.duration > 0 ? parent.width * Math.min(1,
                        (seekMouse.pressed ? root.previewPosition : root.position) / root.duration) : 0
                    height: parent.height
                    radius: 2
                    color: Theme.Colors.accent
                }
            }

            MouseArea {
                id: seekMouse
                width: parent.width
                height: 16
                enabled: root.seekable
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => root.previewPosition = Math.max(0, Math.min(1, mouse.x / width)) * root.duration
                onPositionChanged: mouse => {
                    if (pressed)
                        root.previewPosition = Math.max(0, Math.min(1, mouse.x / width)) * root.duration
                }
                onReleased: {
                    if (root.seekable)
                        root.player.position = root.previewPosition
                }
            }

            Text {
                y: 17
                text: root.player?.positionSupported
                    ? root.formatTime(seekMouse.pressed ? root.previewPosition : root.position) : "--:--"
                color: Theme.Colors.foreground
                opacity: 0.6
                font.pixelSize: 11
            }
            Text {
                anchors.right: parent.right
                y: 17
                text: root.duration > 0 ? root.formatTime(root.duration) : "Live / unknown duration"
                color: Theme.Colors.foreground
                opacity: 0.6
                font.pixelSize: 11
            }
        }

        Item {
            width: parent.width
            height: 40

            Row {
                anchors.centerIn: parent
                spacing: 12

                Components.IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "previous"
                    tooltip: "Previous track"
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player.previous()
                }
                Components.IconButton {
                    width: 40
                    height: 40
                    radius: 20
                    icon: root.player?.isPlaying ? "pause" : "play"
                    tooltip: root.player?.isPlaying ? "Pause" : "Play"
                    highlighted: true
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: root.player.togglePlaying()
                }
                Components.IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "next"
                    tooltip: "Next track"
                    enabled: root.player?.canGoNext ?? false
                    onClicked: root.player.next()
                }
            }
        }
    }
}
