pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var pages: ({})
    property var queue: []
    property int fetching: 0
    readonly property int maxConcurrentFetches: 4

    function firstLink(text, stillWriting) {
        const match = stillWriting ? text.match(/\]\((https?:\/\/[^)\s]+)\)|(https?:\/\/[^\s<>()\]]+)(?=\s)/)
            : text.match(/\]\((https?:\/\/[^)\s]+)\)|(https?:\/\/[^\s<>()\]]+)/)
        return match ? match[1] || match[2] : ""
    }

    function fetch(url) {
        if (!url || url in pages) return
        remember(url, null)
        queue = queue.concat([url])
        startNext()
    }

    function startNext() {
        while (fetching < maxConcurrentFetches && queue.length) {
            const url = queue[0]
            queue = queue.slice(1)
            fetching++
            fetcher.createObject(root, { url: url })
        }
    }

    function remember(url, page) {
        const next = Object.assign({}, pages)
        next[url] = page
        pages = next
    }

    function finished(request, code, errors) {
        fetching--
        request.destroy()
        Qt.callLater(startNext)
        if (code !== 0)
            console.warn("Link preview failed for", request.url + ":", errors.trim())
    }

    Component {
        id: fetcher

        Process {
            id: request
            required property string url
            property bool startedSuccessfully: false

            command: ["link-preview", url]
            running: true
            stdout: SplitParser { onRead: line => root.remember(request.url, JSON.parse(line)) }
            stderr: StdioCollector { id: errors }
            onStarted: startedSuccessfully = true
            onExited: code => root.finished(request, code, errors.text)
            onRunningChanged: if (!running && !startedSuccessfully)
                root.finished(request, -1, "link-preview could not start")
        }
    }
}
