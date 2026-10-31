pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    property var preferredPlayer: null
    readonly property var player: {
        const players = Mpris.players.values
        return players.find(player => player.isPlaying)
            ?? (players.includes(preferredPlayer) ? preferredPlayer : players[0]) ?? null
    }

    // Keep the selected player after pausing instead of jumping to another app.
    onPlayerChanged: Qt.callLater(() => root.preferredPlayer = root.player)
    property bool pipewirePlaying: false
    readonly property bool playing: pipewirePlaying
    readonly property string title: player?.trackTitle || (playing ? "Audio playing" : "No media")
    readonly property string artist: player?.trackArtist || player?.identity || (playing ? "System audio" : "Nothing is playing")

    // The helper listens to PipeWire stream-state events and reconnects if needed.
    Process {
        command: ["pipewire-playback-monitor"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.pipewirePlaying = JSON.parse(data).playing === true
                } catch (error) {
                    console.warn("Invalid PipeWire playback event:", error)
                }
            }
        }
        onExited: root.pipewirePlaying = false
    }
}
