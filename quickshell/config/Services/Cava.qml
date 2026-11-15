pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "." as Services

Singleton {
    id: root

    readonly property int barCount: cavaSetting("bars")
    readonly property int asciiMaxRange: cavaSetting("ascii_max_range")
    property real gain: 1.0
    property var bars: Array(barCount).fill(0)

    function cavaSetting(key) {
        const match = new RegExp("^" + key + "\\s*=\\s*(\\d+)", "m").exec(cavaConfig.text())
        return match ? Number(match[1]) : 0
    }

    function applyFrame(data) {
        const values = data.trim().split(";")
        if (values.length < barCount)
            return
        bars = Array.from({ length: barCount }, (_, index) => {
            const value = Number(values[index])
            return Number.isFinite(value) ? Math.max(0, Math.min(1, value / asciiMaxRange * gain)) : 0
        })
    }

    function groupedBars(count) {
        return Array.from({ length: count }, (_, index) => {
            const firstBand = Math.floor(index * barCount / count)
            const endBand = Math.floor((index + 1) * barCount / count)
            let totalAmplitude = 0
            for (let band = firstBand; band < endBand; band++)
                totalAmplitude += bars[band]
            return totalAmplitude / Math.max(1, endBand - firstBand)
        })
    }

    function syncPlayback() {
        processRestartBackoff.stop()
        if (Services.Media.playing) {
            if (!cavaProcess.running)
                cavaProcess.running = true
        } else {
            cavaProcess.running = false
            bars = Array(barCount).fill(0)
        }
    }

    Component.onCompleted: syncPlayback()

    Connections {
        target: Services.Media
        function onPlayingChanged() { root.syncPlayback() }
    }

    FileView {
        id: cavaConfig
        path: Quickshell.shellPath("Services/cava.conf")
        blockLoading: true
    }

    Process {
        id: cavaProcess
        command: ["cava", "-p", cavaConfig.path]
        stdout: SplitParser {
            onRead: data => root.applyFrame(data)
        }
        onExited: {
            root.bars = Array(root.barCount).fill(0)
            if (Services.Media.playing)
                processRestartBackoff.restart()
        }
    }

    Timer {
        id: processRestartBackoff
        interval: 2000
        onTriggered: root.syncPlayback()
    }
}
