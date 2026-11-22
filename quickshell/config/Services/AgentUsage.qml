pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool shown: false
    property var claude: null
    property var codex: null
    property string claudeError: ""
    property string codexError: ""
    property date checkedAt: new Date(0)
    readonly property bool checking: query.running
    readonly property bool loaded: checkedAt.getTime() > 0
    readonly property bool resetting: redeem.running
    property string resetOutcome: ""
    readonly property int pollInterval: 60000
    property real requestedAt: 0

    onShownChanged: shown ? poll() : pollTimer.stop()

    function refresh() {
        if (!query.running) {
            requestedAt = Date.now()
            query.started = false
            query.running = true
        }
    }

    function poll() {
        if (Date.now() - requestedAt >= pollInterval)
            refresh()
        pollTimer.interval = Math.max(1000, requestedAt + pollInterval - Date.now())
        pollTimer.restart()
    }

    function resetCodex(creditId) {
        if (redeem.running)
            return
        resetOutcome = ""
        redeem.command = ["agent-usage", "reset-codex"].concat(creditId ? [creditId] : [])
        redeem.running = true
    }

    function fail(reason) {
        checkedAt = new Date()
        claudeError = codexError = reason
    }

    function apply(output) {
        const data = JSON.parse(output)
        checkedAt = new Date(data.checkedAt)
        if (data.claude) {
            if (data.claude.available)
                claude = data.claude
            claudeError = data.claude.available ? "" : data.claude.error
        }
        if (data.codex) {
            if (data.codex.available)
                codex = data.codex
            codexError = data.codex.available ? "" : data.codex.error
        }
    }

    Timer {
        id: pollTimer
        onTriggered: root.poll()
    }

    Process {
        id: query
        property bool started: false
        command: ["agent-usage", "--stream"]
        onStarted: started = true
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.apply(data)
                } catch (error) {
                    root.fail("unexpected agent-usage response")
                }
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            if (code !== 0)
                root.fail("agent-usage failed")
        }
        onRunningChanged: {
            if (!running && !started)
                root.fail("agent-usage not installed")
        }
    }

    Process {
        id: redeem
        stdout: StdioCollector { id: redeemOutput }
        stderr: StdioCollector {}
        onExited: code => {
            try {
                const result = JSON.parse(redeemOutput.text)
                root.resetOutcome = result.available ? result.outcome : result.error
            } catch (error) {
                root.resetOutcome = "agent-usage failed"
            }
            root.refresh()
        }
    }
}
