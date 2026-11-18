import QtQuick
import Quickshell.Io

Process {
    id: picker

    property string title
    property string error: ""
    signal picked(string uri)

    function open() {
        if (running) return
        error = ""
        running = true
    }

    command: ["sh", "-c", "command -v pick-image >/dev/null "
        + "|| { echo 'pick-image is not installed. Apply the Home Manager config to add it.' >&2; exit 127; }; "
        + "exec pick-image \"$1\"", "sh", title]
    stdout: StdioCollector {
        onStreamFinished: if (text.trim()) picker.picked(text.trim())
    }
    stderr: StdioCollector {
        id: errors
    }
    onExited: exitCode => {
        if (exitCode !== 0)
            picker.error = errors.text.trim().split("\n").pop() || "The file chooser could not be opened."
    }
}
