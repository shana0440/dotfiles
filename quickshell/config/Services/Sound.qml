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
    readonly property var streams: Pipewire.nodes.values.filter(node => node.audio && node.isStream && node.isSink)

    function devices(input) {
        return Pipewire.nodes.values.filter(node => node.audio && node.isSink !== input && !node.isStream)
    }

    function appEntry(node) {
        const properties = node?.properties ?? {}
        const binary = (properties["application.process.binary"] ?? "").replace(/^\./, "").replace(/-wrapped$/, "")
        return [properties["application.id"], properties["application.name"], binary]
            .filter(name => name)
            .map(name => DesktopEntries.heuristicLookup(name))
            .find(entry => entry) ?? null
    }

    function appName(node) {
        const properties = node?.properties ?? {}
        return appEntry(node)?.name || properties["application.name"] || properties["application.process.binary"]
            || node?.name || ""
    }

    function appIcon(node) {
        const named = node?.properties?.["application.icon-name"]
        return Quickshell.iconPath(named || appEntry(node)?.icon || "", true)
    }

    function findStream(app) {
        const wanted = app.toLowerCase()
        return streams.find(node => String(node.id) === app || appName(node).toLowerCase() === wanted
            || (node.properties?.["application.name"] ?? "").toLowerCase() === wanted)
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
        objects: [root.sink, root.source].filter(node => node).concat(root.streams)
    }

    IpcHandler {
        target: "sound"
        function setVolume(percent: int): void { root.setVolume(root.sink, percent / 100) }
        function toggleMute(): void { root.toggleMute(root.sink) }
        function setInputVolume(percent: int): void { root.setVolume(root.source, percent / 100) }
        function toggleInputMute(): void { root.toggleMute(root.source) }
        function setOutputDevice(name: string): bool { return root.selectNamed(false, name) }
        function setInputDevice(name: string): bool { return root.selectNamed(true, name) }
        function setAppVolume(app: string, percent: int): bool {
            const node = root.findStream(app)
            root.setVolume(node, percent / 100)
            return node !== undefined
        }
        function toggleAppMute(app: string): bool {
            const node = root.findStream(app)
            root.toggleMute(node)
            return node !== undefined
        }
        function state(): string {
            return JSON.stringify({
                output: root.describe(root.sink),
                input: root.describe(root.source),
                apps: root.streams.map(node => Object.assign(root.describe(node), {
                    id: node.id, name: root.appName(node), media: node.properties["media.name"] ?? ""
                })),
                outputDevices: root.devices(false).map(node => ({ name: node.name, label: root.label(node) })),
                inputDevices: root.devices(true).map(node => ({ name: node.name, label: root.label(node) }))
            })
        }
    }
}
