import QtQuick
import Quickshell.Io

Process {
    id: config

    property string error: ""
    signal finished(bool ok, string output)

    function run(args) {
        if (running) return false
        error = ""
        command = ["mei", "config"].concat(args)
        running = true
        return true
    }

    stdout: StdioCollector { id: output }
    stderr: StdioCollector { id: errors }
    onExited: exitCode => {
        if (exitCode !== 0)
            config.error = errors.text.trim().split("\n").pop() || "mei config failed."
        config.finished(exitCode === 0, output.text.trim())
    }
}
