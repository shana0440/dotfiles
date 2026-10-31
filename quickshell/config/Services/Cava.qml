pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "." as Services

Singleton {
    id: root

    // Keep this count aligned with Services/cava.conf.
    readonly property int barCount: 24
    property real gain: 1.0
    property var bars: Array(barCount).fill(0)

    function applyFrame(data) {
        const values = data.trim().split(";")
        if (values.length < barCount)
            return
        bars = Array.from({ length: barCount }, (_, index) => {
            const value = Number(values[index])
            return Number.isFinite(value) ? Math.max(0, Math.min(1, value / 100 * gain)) : 0
        })
    }

    // Average adjacent frequency bands for a smaller version of the same spectrum.
    function groupedBars(count) {
        return Array.from({ length: count }, (_, index) => {
            const start = Math.floor(index * barCount / count)
            const end = Math.floor((index + 1) * barCount / count)
            let sum = 0
            for (let band = start; band < end; band++)
                sum += bars[band]
            return sum / Math.max(1, end - start)
        })
    }

    function sync() {
        restartTimer.stop()
        if (Services.Media.playing) {
            if (!cavaProcess.running)
                cavaProcess.running = true
        } else {
            cavaProcess.running = false
            bars = Array(barCount).fill(0)
        }
    }

    Component.onCompleted: sync()

    Connections {
        target: Services.Media
        function onPlayingChanged() { root.sync() }
    }

    Process {
        id: cavaProcess
        command: ["cava", "-p", Quickshell.shellPath("Services/cava.conf")]
        stdout: SplitParser {
            onRead: data => root.applyFrame(data)
        }
        onExited: {
            root.bars = Array(root.barCount).fill(0)
            if (Services.Media.playing)
                restartTimer.restart()
        }
    }

    // Supervise the process, not playback detection.
    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: root.sync()
    }
}
