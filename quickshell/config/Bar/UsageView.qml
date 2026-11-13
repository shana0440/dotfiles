import QtQuick
import "../Theme" as Theme
import "../Components" as Components

// The dashboard's usage tab: how much of each subscription's 5-hour and weekly
// limits is spent, and when each resets.
Item {
    id: root

    property bool active: false
    // Reset countdowns tick once a minute.
    property date now: new Date()

    implicitWidth: 480
    implicitHeight: content.implicitHeight + 40

    AgentUsage {
        id: usage
        active: root.active
    }

    Timer {
        interval: 30000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // "Reset in 3h 55m (23:20)" within a day, "Reset in 6d 9h (Fri 05:00)" beyond.
    function resetText(iso) {
        if (!iso)
            return ""
        const at = new Date(iso)
        const minutes = Math.max(0, Math.round((at - now) / 60000))
        const hours = Math.floor(minutes / 60)
        if (minutes < 24 * 60)
            return "Reset in " + (hours > 0 ? hours + "h " : "") + (minutes % 60) + "m (" + Qt.formatDateTime(at, "HH:mm") + ")"
        return "Reset in " + Math.floor(hours / 24) + "d " + (hours % 24) + "h (" + Qt.formatDateTime(at, "ddd HH:mm") + ")"
    }

    function errorText(error) {
        return ({
            "not signed in": "Not signed in",
            "login expired": "Login expired, open Pi to renew",
            "login rejected": "Login rejected",
            "unreachable": "Offline",
            "unexpected response": "Unexpected response",
            "agent-usage not installed": "agent-usage not installed"
        })[error] ?? error
    }

    component Limit: Column {
        id: limit
        property string label: ""
        property var span: null
        readonly property real percent: span && span.percent !== null && span.percent !== undefined ? span.percent : -1
        readonly property bool full: percent >= 100
        readonly property bool high: percent >= 80 || (span && span.severity && span.severity !== "normal")
        readonly property color tone: full ? Theme.Colors.error : high ? Theme.Colors.warning : Theme.Colors.foreground

        width: parent.width
        spacing: 6

        Item {
            width: parent.width
            height: limitLabel.implicitHeight

            Text {
                id: limitLabel
                text: limit.label
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right
                anchors.baseline: limitLabel.baseline
                text: limit.percent >= 0 ? Math.round(limit.percent) + "%" : "—"
                color: limit.tone
                font.family: Theme.Fonts.mono
                font.pixelSize: 13
            }
        }
        Rectangle {
            id: track
            width: parent.width
            height: 6
            radius: 3
            color: Theme.Colors.track
            opacity: limit.percent >= 0 ? 1 : 0.5

            Rectangle {
                width: fill.value
                height: parent.height
                radius: parent.radius
                color: limit.tone

                Components.Spring {
                    id: fill
                    to: track.width * Math.max(0, Math.min(1, limit.percent / 100))
                    stiffness: Theme.Motion.stackStiffness
                    damping: Theme.Motion.stackDamping
                }
            }
        }
        Text {
            text: limit.span ? root.resetText(limit.span.resetsAt) : ""
            visible: text.length > 0
            color: Theme.Colors.muted
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 11
        }
    }

    component ProviderCard: Rectangle {
        id: card
        property string name: ""
        property string plan: ""
        property var reading: null
        property string error: ""

        width: content.width
        height: cardContent.implicitHeight + 32
        radius: 12
        color: Theme.Colors.surface

        Column {
            id: cardContent
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 14

            Item {
                width: parent.width
                height: cardName.implicitHeight

                Text {
                    id: cardName
                    text: card.name
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 15
                }
                Text {
                    anchors.right: parent.right
                    anchors.baseline: cardName.baseline
                    // A failed check keeps the last reading and says why it is stale.
                    text: card.error ? root.errorText(card.error) + (card.reading ? " \u00b7 stale" : "")
                        : card.plan
                    color: card.error ? Theme.Colors.warning : Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }
            }

            Limit {
                label: "5-hour limit"
                span: card.reading ? card.reading.fiveHour : null
            }
            Limit {
                label: "Weekly limit"
                span: card.reading ? card.reading.weekly : null
            }

            // Weekly limits that apply to one model only.
            Repeater {
                model: card.reading ? card.reading.models.length : 0

                Limit {
                    required property int index
                    readonly property var entry: card.reading?.models[index] ?? null
                    label: entry ? entry.name + " weekly" : ""
                    span: entry
                }
            }
        }
    }

    Column {
        id: content
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 16

        Item {
            width: parent.width
            height: 32

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Usage"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    text: usage.checking && !usage.loaded ? "Checking"
                        : usage.loaded ? "Checked " + Qt.formatDateTime(usage.checkedAt, "HH:mm") + " \u00b7 every 2 minutes" : ""
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }
            }
            Components.IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                iconSize: 16
                icon: "reboot"
                tooltip: usage.checking ? "Checking" : "Check now"
                enabled: !usage.checking
                onClicked: usage.refresh()
            }
        }

        ProviderCard {
            name: "Claude"
            reading: usage.claude
            error: usage.claudeError
        }
        ProviderCard {
            name: "Codex"
            plan: usage.codex && usage.codex.plan ? usage.codex.plan.charAt(0).toUpperCase() + usage.codex.plan.slice(1) + " plan" : ""
            reading: usage.codex
            error: usage.codexError
        }
    }
}
