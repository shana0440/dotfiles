pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio ?? null
    readonly property real volume: audio?.volume ?? 0
    readonly property bool muted: audio?.muted ?? false

    function setVolume(node, value) {
        if (!node?.audio)
            return
        node.audio.volume = Math.max(0, Math.min(1, value))
        node.audio.muted = false
    }

    function toggleMute(node) {
        if (node?.audio)
            node.audio.muted = !node.audio.muted
    }

    function describe(node) {
        return node ? {
            name: node.description || node.nickname || node.name,
            volume: Math.round((node.audio?.volume ?? 0) * 100),
            muted: node.audio?.muted ?? false
        } : null
    }

    PwObjectTracker {
        objects: [root.sink].filter(node => node)
    }

    IpcHandler {
        target: "sound"
        function setVolume(percent: int): void { root.setVolume(root.sink, percent / 100) }
        function toggleMute(): void { root.toggleMute(root.sink) }
        function state(): string {
            return JSON.stringify({ output: root.describe(root.sink) })
        }
    }
}
