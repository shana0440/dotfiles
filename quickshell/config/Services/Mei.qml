pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("MEI_HOME") || Quickshell.env("HOME") + "/.local/share/mei"
    readonly property string socketPath: home + "/state/mei.sock"
    readonly property string character: characterFile.text()
    property string characterFileName: "CHARACTER.md"
    readonly property string characterTitle: characterFileName.split("/").pop()
    property string configuredName: ""
    readonly property string name: configuredName || "mei"
    readonly property bool renaming: nameWriter.running
    readonly property string avatar: profile.avatar
    readonly property bool choosingAvatar: avatarPicker.running
    readonly property string avatarError: avatarPicker.error
    property var schedules: []
    property string scheduleError: ""
    property string changingSchedule: ""
    property bool resetting: false
    readonly property ListModel messages: ListModel {}
    property int waiting: 0
    property string activity: ""
    property bool reachable: true
    property string lastTopic: ""
    property bool chatInView: false
    property int historyVersion: 0
    signal openRequested()
    readonly property string presence: !reachable ? "offline"
        : activity ? activity
        : waiting > 0 ? "typing…" : "online"

    function clock(ms) {
        return Qt.formatTime(new Date(ms), "hh:mm")
    }

    function imageUrl(path) {
        if (/^(https?|file):\/\//.test(path)) return path
        if (path.startsWith("~/")) path = Quickshell.env("HOME") + path.slice(1)
        else if (!path.startsWith("/")) path = home + "/" + path
        return "file://" + path.split("/").map(encodeURIComponent).join("/")
    }

    function splitPhotos(text) {
        const photos = []
        const keep = (match, path, plainPath) => { photos.push(imageUrl(path || plainPath)); return "" }
        const caption = text
            .replace(/!\[[^\]]*\]\((?:<([^>]+)>|([^)\s]+))(?:\s+"[^"]*")?\)/g, keep)
            .replace(/^[ \t]*`?((?:https?:\/\/|file:\/\/|~\/|\/)\S+\.(?:png|jpe?g|gif|webp|bmp|svg))`?[ \t]*$/gmi, keep)
            .replace(/\n{3,}/g, "\n\n")
            .trim()
        return { caption: caption, photos: photos }
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
        historyVersion++
        append("user", trimmed, Date.now())
        waiting++
        requestComponent.createObject(root, { message: { type: "chat", text: trimmed, debug: true } })
    }

    function announce(reply) {
        if (chatInView || !reply.trim()) return
        const caption = splitPhotos(reply).caption || "Photo"
        const plain = caption.replace(/^#+\s*/gm, "").replace(/[*`]+/g, "").trim()
        replyNotification.createObject(root, { body: plain })
    }

    function readConfig() {
        nameReader.run(["get", "character.name"])
        characterFileReader.run(["get", "character.file"])
    }

    function rename(newName, finished) {
        nameWriter.whenDone = finished
        if (!nameWriter.run(["set", "character.name", JSON.stringify(newName.trim())]))
            finished("mei is still saving the last change.")
    }

    function saveCharacter(text) {
        characterFile.setText(text)
    }

    function chooseAvatar() {
        avatarPicker.open()
    }

    function removeAvatar() {
        profile.avatar = ""
    }

    function ask(message, answer) {
        requestComponent.createObject(root, { message: message, answer: answer })
    }

    function loadSchedules(changeError) {
        ask({ type: "schedules" }, reply => {
            schedules = reply.schedules ?? []
            changingSchedule = ""
            scheduleError = reply.error ?? changeError ?? ""
        })
    }

    function changeSchedule(action, name) {
        if (changingSchedule) return
        changingSchedule = name
        ask({ type: "schedule", change: { action: action, name: name } }, reply => {
            loadSchedules(reply.error)
        })
    }

    function resetMemory(finished) {
        if (resetting) return
        resetting = true
        historyVersion++
        ask({ type: "reset" }, reply => {
            resetting = false
            if (!reply.error) {
                historyVersion++
                messages.clear()
                lastTopic = ""
            }
            finished(reply.error ?? "")
        })
    }

    function refresh() {
        if (waiting > 0) return
        requestComponent.createObject(root, { message: { type: "status" }, historyVersion: historyVersion })
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
            property var answer: null
            property int historyVersion: -1
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

            function showTopic(topic) {
                if (!topic || topic === root.lastTopic) return
                root.lastTopic = topic
                root.messages.set(replyRow, { kind: "topic", text: topic, streaming: false })
                replyRow = -1
                showTyping()
            }

            function finish(reply) {
                answered = true
                root.reachable = true
                if (answer) {
                    answer(reply)
                    return
                }
                if (message.type === "status") {
                    if (historyVersion === root.historyVersion)
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
                root.announce(reply.result)
            }

            function handle(line) {
                let data
                try { data = JSON.parse(line) } catch (_) { return }
                if (data.type === "mei_route") {
                    showTyping()
                    showTopic(data.topic)
                } else if (data.type === "tool_execution_start") {
                    root.activity = "using " + data.toolName + "…"
                    showTyping()
                } else if (data.type === "message_update") {
                    const update = data.assistantMessageEvent
                    if (update.type === "text_start") root.activity = ""
                    if (["text_start", "thinking_start", "toolcall_start"].includes(update.type))
                        showTyping()
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
                if (answer) answer({ error: "mei is not running." })
                else if (message.type === "chat") {
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
                    if (message.type === "chat") showTyping()
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

    Component {
        id: replyNotification

        Process {
            id: notification
            required property string body
            readonly property string icon: root.avatar.startsWith("file://")
                ? decodeURIComponent(root.avatar.slice("file://".length)) : root.avatar

            command: ["notify-send", "--app-name=" + root.name, "--icon=" + icon,
                "--action=open=Reply", "--wait", root.name, body]
            running: true
            stdout: StdioCollector {
                onStreamFinished: if (text.trim() === "open") root.openRequested()
            }
            onExited: notification.destroy()
        }
    }

    FileView {
        id: configFile
        path: root.home + "/config.toml"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload()
            root.readConfig()
        }
    }

    MeiConfig {
        id: characterFileReader
        onFinished: (ok, output) => { if (ok) root.characterFileName = output }
    }

    MeiConfig {
        id: nameReader
        onFinished: (ok, output) => { if (ok) root.configuredName = output }
    }

    MeiConfig {
        id: nameWriter
        property var whenDone: null
        onFinished: ok => {
            if (ok) nameReader.run(["get", "character.name"])
            whenDone?.(ok ? "" : error)
        }
    }

    FileView {
        id: characterFile
        path: root.characterFileName.startsWith("/") ? root.characterFileName
            : root.home + "/" + root.characterFileName
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

    ImagePicker {
        id: avatarPicker
        title: "Choose a photo for " + root.name
        onPicked: uri => profile.avatar = uri
    }

    Component.onCompleted: {
        refresh()
        readConfig()
    }
}
