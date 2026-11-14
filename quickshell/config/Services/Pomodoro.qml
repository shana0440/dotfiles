pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// A pomodoro timer: 25 minutes of focus, then a 5 minute break, with a 15 minute
// break after every fourth focus. A finished phase sends a notification and waits
// for a start, so a break never begins unnoticed. The state is kept in the shell's
// state directory as an end time, so a running timer survives a shell reload.
Singleton {
    id: root

    readonly property var phases: ({
        focus: { label: "Focus", minutes: 25 },
        shortBreak: { label: "Short break", minutes: 5 },
        longBreak: { label: "Long break", minutes: 15 }
    })
    readonly property int sessionsPerRound: 4

    readonly property string phase: phases[saved.phase] ? saved.phase : "focus"
    readonly property string label: phases[phase].label
    readonly property int duration: phases[phase].minutes * 60 * 1000
    readonly property bool running: saved.endsAt > 0
    // Focus sessions finished in the current round of four.
    readonly property int completed: saved.completed % sessionsPerRound
    // Milliseconds left in the phase, refreshed every second while running.
    property real now: Date.now()
    readonly property real remaining: running ? Math.max(0, saved.endsAt - now)
        : saved.remaining > 0 ? Math.min(saved.remaining, duration) : duration
    readonly property real progress: 1 - remaining / duration

    // "12:34", rounded up so the last second reads 00:01, not 00:00.
    function format(ms) {
        const seconds = Math.ceil(ms / 1000)
        return String(Math.floor(seconds / 60)).padStart(2, "0") + ":" + String(seconds % 60).padStart(2, "0")
    }

    function start() {
        if (running)
            return
        now = Date.now()
        saved.endsAt = now + remaining
        saved.remaining = 0
    }

    function pause() {
        if (!running)
            return
        now = Date.now()
        saved.remaining = remaining
        saved.endsAt = 0
    }

    function toggle() {
        running ? pause() : start()
    }

    // Back to the start of the current phase, stopped.
    function reset() {
        saved.endsAt = 0
        saved.remaining = 0
    }

    // Stops on the start of another phase.
    function select(name) {
        if (!phases[name])
            return
        saved.phase = name
        reset()
    }

    // Ends the phase early, without counting a skipped focus.
    function skip() {
        advance(false)
    }

    function advance(finished) {
        if (phase === "focus") {
            if (finished)
                saved.completed++
            const round = finished && saved.completed % sessionsPerRound === 0
            select(round ? "longBreak" : "shortBreak")
        } else {
            // A new round starts after the long break.
            if (phase === "longBreak")
                saved.completed = 0
            select("focus")
        }
    }

    function finish() {
        const ended = phase
        advance(true)
        const body = ended === "focus" ? label + " for " + phases[phase].minutes + " minutes"
            : "Next: " + phases.focus.minutes + " minutes of focus"
        Quickshell.execDetached(["notify-send", "--app-name=Pomodoro", "--icon=alarm-symbolic",
            ended === "focus" ? "Focus done" : "Break over", body])
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now()
            if (root.remaining <= 0)
                root.finish()
        }
    }

    IpcHandler {
        target: "pomodoro"
        function toggle(): void { root.toggle() }
        function reset(): void { root.reset() }
        function skip(): void { root.skip() }
    }

    // Only this shell writes the file, so it is read once and not watched.
    FileView {
        path: Quickshell.statePath("pomodoro.json")
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: saved
            property string phase: "focus"
            // Epoch ms the running phase ends at; 0 while stopped.
            property real endsAt: 0
            // Time left in a paused phase; 0 when it has not started.
            property real remaining: 0
            property int completed: 0
        }
    }
}
