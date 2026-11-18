pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("MEI_HOME") || Quickshell.env("HOME") + "/.local/share/mei"
    readonly property string socketPath: home + "/state/mei.sock"
    readonly property string name: characterFile.text().match(/^- Name:[ \t]*(.*\S)/m)?.[1] ?? "mei"
    readonly property string avatar: profile.avatar
    readonly property bool choosingAvatar: avatarPicker.running
    readonly property ListModel messages: ListModel {}
    property int waiting: 0
    property string activity: ""
    property bool reachable: true
    property string lastTopic: ""
    readonly property string presence: !reachable ? "offline"
        : activity ? activity
        : waiting > 0 ? "typing…" : "online"

    function clock(ms) {
        return Qt.formatTime(new Date(ms), "hh:mm")
    }

    function append(kind, text, ms) {
        messages.append({ kind: kind, text: text, time: ms ? clock(ms) : "", streaming: false })
        return messages.count - 1
    }

    function noteTopic(topic) {
        if (!topic || topic === lastTopic) return
        lastTopic = topic
        append("topic", topic, 0)
    }

    function send(text) {
        const trimmed = text.trim()
        if (!trimmed) return
        append("user", trimmed, Date.now())
        waiting++
        requestComponent.createObject(root, { message: { type: "chat", text: trimmed, debug: true } })
    }

    function rename(newName) {
        const trimmed = newName.trim().replace(/\s+/g, " ")
        if (!trimmed || trimmed === name) return
        const text = characterFile.text()
        const line = "- Name: " + trimmed
        characterFile.setText(/^- Name:.*$/m.test(text) ? text.replace(/^- Name:.*$/m, line)
            : text.trim() ? text.trimEnd() + "\n" + line + "\n"
            : "# Character\n\n" + line + "\n")
    }

    function chooseAvatar() {
        if (!avatarPicker.running) avatarPicker.running = true
    }

    function removeAvatar() {
        profile.avatar = ""
    }

    function refresh() {
        if (waiting > 0) return
        requestComponent.createObject(root, { message: { type: "status" } })
    }

    function showHistory(events) {
        messages.clear()
        lastTopic = ""
        for (const event of events) {
            if (event.type !== "user.message" || (event.status !== "done" && event.status !== "failed")) continue
            append("user", event.payload.text, event.createdAt)
            noteTopic(event.topic)
            if (event.error) append("notice", event.error, 0)
            else append("mei", event.result, event.finishedAt)
        }
    }

    Component {
        id: requestComponent

        Socket {
            id: request
            required property var message
            property int replyRow: -1
            property bool answered: false
            property bool opened: false

            function stream(text) {
                if (replyRow < 0) {
                    replyRow = root.append("mei", "", 0)
                    root.messages.setProperty(replyRow, "streaming", true)
                }
                root.messages.setProperty(replyRow, "text", text)
            }

            function showTyping() {
                if (replyRow >= 0 && root.messages.get(replyRow).text !== "") {
                    root.messages.setProperty(replyRow, "streaming", false)
                    root.messages.setProperty(replyRow, "time", root.clock(Date.now()))
                    replyRow = -1
                }
                stream("")
            }

            function finish(reply) {
                answered = true
                root.reachable = true
                if (message.type === "status") {
                    root.showHistory(reply.events ?? [])
                    return
                }
                root.waiting--
                root.activity = ""
                if (reply.error) {
                    if (replyRow >= 0) root.messages.remove(replyRow)
                    root.append("notice", reply.error, 0)
                    return
                }
                root.noteTopic(reply.topic)
                stream(reply.result)
                root.messages.setProperty(replyRow, "streaming", false)
                root.messages.setProperty(replyRow, "time", root.clock(Date.now()))
            }

            function handle(line) {
                let data
                try { data = JSON.parse(line) } catch (_) { return }
                if (data.type === "mei_route") {
                    root.noteTopic(data.topic)
                    stream("")
                } else if (data.type === "tool_execution_start") {
                    root.activity = "using " + data.toolName + "…"
                    showTyping()
                } else if (data.type === "message_update") {
                    const update = data.assistantMessageEvent
                    if (update.type === "text_start") {
                        root.activity = ""
                        if (replyRow >= 0) stream("")
                    }
                    if (update.type === "text_delta")
                        stream((replyRow >= 0 ? root.messages.get(replyRow).text : "") + update.delta)
                } else if (!data.type) {
                    finish(data)
                }
            }

            function giveUp() {
                if (answered) return
                answered = true
                root.reachable = false
                if (message.type === "chat") {
                    root.waiting--
                    root.activity = ""
                    root.append("notice", "mei is not running, so the message was not sent.", 0)
                }
            }

            path: root.socketPath
            connected: true
            parser: SplitParser { onRead: line => request.handle(line) }
            onConnectionStateChanged: {
                if (connected) {
                    opened = true
                    write(JSON.stringify(message) + "\n")
                    flush()
                } else {
                    if (!answered) giveUp()
                    Qt.callLater(() => request.destroy())
                }
            }
            onError: {
                if (opened) return
                giveUp()
                Qt.callLater(() => request.destroy())
            }
        }
    }

    FileView {
        id: characterFile
        path: root.home + "/CHARACTER.md"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    FileView {
        path: Quickshell.statePath("mei.json")
        blockLoading: true
        watchChanges: false
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: profile
            property string avatar: ""
        }
    }

    Process {
        id: avatarPicker
        command: ["pick-image", "Choose a photo for " + root.name]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) profile.avatar = text.trim()
        }
    }

    Component.onCompleted: refresh()
}
