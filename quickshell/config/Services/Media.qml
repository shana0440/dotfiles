pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    property var lastSelectedPlayer: null
    readonly property var player: {
        const players = Mpris.players.values
        return players.find(player => player.isPlaying)
            ?? (players.includes(lastSelectedPlayer) ? lastSelectedPlayer : players[0]) ?? null
    }

    // Defer this assignment to avoid re-entering the player-selection binding.
    onPlayerChanged: Qt.callLater(() => root.lastSelectedPlayer = root.player)
    property bool pipewirePlaying: false
    readonly property bool playing: pipewirePlaying
    readonly property string title: player?.trackTitle || (playing ? "Audio playing" : "No media")
    readonly property string artist: player?.trackArtist || player?.identity || (playing ? "System audio" : "Nothing is playing")

    Process {
        id: playbackMonitor
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
