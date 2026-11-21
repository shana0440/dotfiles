pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var audio: sink?.audio ?? null
    readonly property real volume: audio?.volume ?? 0
    readonly property bool muted: audio?.muted ?? false

    function devices(input) {
        return Pipewire.nodes.values.filter(node => node.audio && node.isSink !== input && !node.isStream)
    }

    function label(node) {
        return node ? node.description || node.nickname || node.name : ""
    }

    function select(input, node) {
        if (input)
            Pipewire.preferredDefaultAudioSource = node
        else
            Pipewire.preferredDefaultAudioSink = node
    }

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
            name: label(node),
            volume: Math.round((node.audio?.volume ?? 0) * 100),
            muted: node.audio?.muted ?? false
        } : null
    }

    function selectNamed(input, name) {
        const node = devices(input).find(node => node.name === name || label(node) === name)
        if (node)
            select(input, node)
        return node !== undefined
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => node)
    }

    IpcHandler {
        target: "sound"
        function setVolume(percent: int): void { root.setVolume(root.sink, percent / 100) }
        function toggleMute(): void { root.toggleMute(root.sink) }
        function setInputVolume(percent: int): void { root.setVolume(root.source, percent / 100) }
        function toggleInputMute(): void { root.toggleMute(root.source) }
        function setOutputDevice(name: string): bool { return root.selectNamed(false, name) }
        function setInputDevice(name: string): bool { return root.selectNamed(true, name) }
        function state(): string {
            return JSON.stringify({
                output: root.describe(root.sink),
                input: root.describe(root.source),
                outputDevices: root.devices(false).map(node => ({ name: node.name, label: root.label(node) })),
                inputDevices: root.devices(true).map(node => ({ name: node.name, label: root.label(node) }))
            })
        }
    }
}
