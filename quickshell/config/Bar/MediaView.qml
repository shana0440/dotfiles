import QtQuick
import Quickshell.Widgets
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

// Now playing: source and state, artwork with track details, a spectrum that doubles
// as progress, the seek bar, and transport controls.
Item {
    id: root

    property bool active: false
    readonly property var player: Services.Media.player
    readonly property bool isPlaying: root.player?.isPlaying ?? false
    readonly property real duration: player?.lengthSupported ? Math.max(0, player.length) : 0
    readonly property real position: player?.positionSupported ? Math.max(0, player.position) : 0
    readonly property bool seekable: (player?.canSeek ?? false)
        && (player?.positionSupported ?? false) && duration > 0
    property real previewPosition: 0
    readonly property real shownPosition: seekMouse.pressed ? previewPosition : position
    // Without a known length the whole spectrum stays live.
    readonly property real progress: duration > 0 ? Math.min(1, shownPosition / duration) : 1

    implicitWidth: 480
    implicitHeight: content.implicitHeight + 40

    function formatTime(seconds) {
        const value = Math.max(0, Math.floor(seconds))
        const minutes = Math.floor(value / 60)
        return minutes + ":" + String(value % 60).padStart(2, "0")
    }

    function seekFraction(x, width) {
        return Math.max(0, Math.min(1, x / width)) * duration
    }

    // MPRIS position needs explicit refreshes to advance the seek bar during playback.
    Timer {
        interval: 250
        repeat: true
        running: root.active && root.isPlaying
        onTriggered: root.player.positionChanged()
    }

    Column {
        id: content
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 16

        // The same header as the other tabs: title, then the source and state under it.
        Item {
            width: parent.width
            height: 32

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40
                spacing: 2

                Text {
                    text: "Now playing"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    readonly property string state: root.isPlaying || Services.Media.playing ? "Playing"
                        : root.player ? "Paused" : "Nothing playing"
                    width: parent.width
                    text: root.player?.identity ? root.player.identity + " · " + state : state
                    textFormat: Text.PlainText
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 14
                    spacing: 2

                    Repeater {
                        model: 3

                        Rectangle {
                            required property int index
                            readonly property var levels: Services.Cava.groupedBars(3)
                            anchors.bottom: parent.bottom
                            width: 3
                            height: Services.Media.playing
                                ? Math.max(4, parent.height * (levels[index] ?? 0)) : 4
                            radius: 1.5
                            color: Theme.Colors.muted

                            Behavior on height {
                                SmoothedAnimation { velocity: 120 }
                            }
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 120
            spacing: 20

            ClippingRectangle {
                width: 120
                height: 120
                radius: 12
                color: Theme.Colors.surface

                Image {
                    id: artwork
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 240
                    sourceSize.height: 240
                }

                Components.Icon {
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    action: "audio"
                    iconColor: Theme.Colors.muted
                    visible: artwork.status !== Image.Ready
                }
            }

            Column {
                width: parent.width - 120 - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    width: parent.width
                    text: Services.Media.title
                    textFormat: Text.PlainText
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 20
                    font.bold: true
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: Services.Media.artist
                    textFormat: Text.PlainText
                    color: Theme.Colors.foreground
                    opacity: 0.75
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
                Row {
                    width: parent.width
                    spacing: 6
                    visible: album.text.length > 0

                    Components.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        action: "album"
                        iconColor: Theme.Colors.muted
                    }
                    Text {
                        id: album
                        width: parent.width - 20
                        text: root.player?.trackAlbum ?? ""
                        textFormat: Text.PlainText
                        color: Theme.Colors.muted
                        font.family: Theme.Fonts.family
                        font.weight: Theme.Fonts.weight
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Bars up to the playhead move with the audio; the rest wait as dashes.
        Row {
            id: spectrum
            width: parent.width
            height: 32
            spacing: 4

            Repeater {
                model: Services.Cava.barCount

                Rectangle {
                    required property int index
                    readonly property bool played: (index + 0.5) / Services.Cava.barCount <= root.progress

                    anchors.verticalCenter: parent.verticalCenter
                    width: (spectrum.width - (Services.Cava.barCount - 1) * spectrum.spacing) / Services.Cava.barCount
                    height: played ? Math.max(width, spectrum.height * (Services.Cava.bars[index] ?? 0)) : 3
                    radius: Math.min(width, height) / 2
                    color: played ? Theme.Colors.foreground : Theme.Colors.track
                    opacity: played ? 0.85 : 1

                    Behavior on height {
                        SmoothedAnimation { velocity: 240 }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 40

            Rectangle {
                id: track
                y: 6
                width: parent.width
                height: 4
                radius: 2
                color: Theme.Colors.track

                Rectangle {
                    width: root.duration > 0 ? parent.width * root.progress : 0
                    height: parent.height
                    radius: 2
                    color: Theme.Colors.foreground
                }
            }

            Rectangle {
                visible: root.duration > 0
                x: track.width * root.progress - width / 2
                y: track.y + track.height / 2 - height / 2
                width: seekMouse.pressed ? 16 : 14
                height: width
                radius: width / 2
                color: Theme.Colors.foreground

                Behavior on width {
                    NumberAnimation { duration: 120 }
                }
            }

            MouseArea {
                id: seekMouse
                width: parent.width
                height: 20
                enabled: root.seekable
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => root.previewPosition = root.seekFraction(mouse.x, width)
                onPositionChanged: mouse => {
                    if (pressed)
                        root.previewPosition = root.seekFraction(mouse.x, width)
                }
                onReleased: {
                    if (root.seekable)
                        root.player.position = root.previewPosition
                }
            }

            Text {
                y: 24
                text: root.player?.positionSupported ? root.formatTime(root.shownPosition) : "--:--"
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 12
                font.features: ({ "tnum": 1 })
            }
            Text {
                anchors.right: parent.right
                y: 24
                text: root.duration > 0 ? "-" + root.formatTime(root.duration - root.shownPosition) : "Live"
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 12
                font.features: ({ "tnum": 1 })
            }
        }

        Item {
            width: parent.width
            height: 56

            Row {
                anchors.centerIn: parent
                spacing: 28

                Components.IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 20
                    iconSize: 22
                    icon: "previous"
                    tooltip: "Previous track"
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player.previous()
                }
                Components.IconButton {
                    width: 56
                    height: 56
                    radius: 28
                    iconSize: 24
                    icon: root.isPlaying ? "pause" : "play"
                    tooltip: root.isPlaying ? "Pause" : "Play"
                    highlighted: true
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: root.player.togglePlaying()
                }
                Components.IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 20
                    iconSize: 22
                    icon: "next"
                    tooltip: "Next track"
                    enabled: root.player?.canGoNext ?? false
                    onClicked: root.player.next()
                }
            }
        }
    }
}
