import QtQuick
import Quickshell.Io

// Claude and Codex subscription limits from the agents module's agent-usage,
// polled every 2 minutes while active.
Item {
    id: root

    property bool active: false
    // The last good reading of each provider; a failed check keeps it and sets error.
    property var claude: null
    property var codex: null
    property string claudeError: ""
    property string codexError: ""
    property date checkedAt: new Date(0)
    readonly property bool checking: query.running
    readonly property bool loaded: checkedAt.getTime() > 0

    visible: false

    function refresh() {
        if (!query.running) {
            query.started = false
            query.running = true
        }
    }

    function fail(reason) {
        checkedAt = new Date()
        claudeError = codexError = reason
    }

    function apply(output) {
        const data = JSON.parse(output)
        checkedAt = new Date(data.checkedAt)
        if (data.claude.available)
            claude = data.claude
        claudeError = data.claude.available ? "" : data.claude.error
        if (data.codex.available)
            codex = data.codex
        codexError = data.codex.available ? "" : data.codex.error
    }

    Timer {
        interval: 120000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: query
        property bool started: false
        command: ["agent-usage"]
        onStarted: started = true
        stdout: StdioCollector { id: queryOutput }
        stderr: StdioCollector {}
        onExited: code => {
            if (code === 0) {
                root.apply(queryOutput.text)
                return
            }
            root.fail("agent-usage failed")
        }
        // FailedToStart (not installed) emits runningChanged but not exited.
        onRunningChanged: {
            if (!running && !started)
                root.fail("agent-usage not installed")
        }
    }
}
