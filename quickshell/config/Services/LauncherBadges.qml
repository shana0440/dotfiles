pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var badges: ({})

    function hasUnread(appId, desktopId) {
        for (const id of [desktopId, appId]) {
            if (!id)
                continue
            // IDs may already include the file extension, or merely end in
            // '.desktop' as part of their stem (org.telegram.desktop.desktop).
            for (const key of [id, id + ".desktop"]) {
                const badge = badges[key]
                if (badge && (badge.count > 0 || badge.urgent === true))
                    return true
            }
        }
        return false
    }

    Process {
        id: monitor
        command: ["launcher-badge-monitor"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.badges = JSON.parse(data)
                } catch (error) {
                    root.badges = ({})
                    console.warn("Invalid launcher badge state:", error)
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                root.badges = ({})
                retry.restart()
            }
        }
    }

    Timer {
        id: retry
        interval: 2000
        onTriggered: monitor.running = true
    }
}
