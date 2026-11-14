import QtQuick
import "../Theme" as Theme
import "../Components" as Components

// The dashboard's usage tab: how much of each subscription's 5-hour and weekly
// limits is spent, when each resets, and any earned Codex limit resets to redeem.
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

    function expiryText(iso) {
        return iso ? "Expires " + Qt.formatDateTime(new Date(iso), "MMM d") : "Does not expire"
    }

    function outcomeText(outcome) {
        return ({
            "reset": "Limits reset",
            "nothing_to_reset": "Nothing to reset, credit kept",
            "no_credit": "No resets left",
            "already_redeemed": "Already used"
        })[outcome] ?? "Couldn't reset: " + errorText(outcome)
    }

    component TextButton: Rectangle {
        id: button
        property string label: ""
        property bool primary: false
        signal clicked()

        implicitWidth: buttonText.implicitWidth + 24
        implicitHeight: 28
        radius: 8
        color: primary ? (buttonMouse.containsMouse ? Qt.tint(Theme.Colors.foreground, "#2e0c0c0d") : Theme.Colors.foreground)
            : buttonMouse.containsMouse || activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
        border.width: primary ? 0 : 1
        border.color: Theme.Colors.ring
        opacity: enabled ? 1 : 0.4
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            color: button.primary ? Theme.Colors.background : Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 12
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    // One earned Codex reset. Like the power tab, redeeming takes a second click
    // within 4 seconds; the
    // backend only accepts it while a limit is spent enough to need it.
    component ResetCredit: Item {
        id: credit
        property var entry: null
        property bool applicable: false
        property bool armed: false

        width: parent.width
        height: Math.max(creditText.implicitHeight, use.implicitHeight)

        Column {
            id: creditText
            anchors.left: parent.left
            anchors.right: use.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: credit.entry && credit.entry.title ? credit.entry.title : "Limit reset"
                elide: Text.ElideRight
                color: Theme.Colors.foreground
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 13
            }
            Text {
                width: parent.width
                text: root.expiryText(credit.entry ? credit.entry.expiresAt : null)
                    + (credit.applicable ? "" : " \u00b7 not needed yet")
                elide: Text.ElideRight
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 11
            }
        }
        TextButton {
            id: use
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            label: usage.resetting ? "Resetting" : credit.armed ? "Confirm reset" : "Use reset"
            primary: credit.armed
            enabled: credit.applicable && !usage.resetting
            onClicked: {
                if (!credit.armed) {
                    credit.armed = true
                    disarm.restart()
                    return
                }
                credit.armed = false
                usage.resetCodex(credit.entry ? credit.entry.id : "")
            }

            Timer {
                id: disarm
                interval: 4000
                onTriggered: credit.armed = false
            }
        }

        // Like the power tab, leaving the tab cancels a pending second click.
        Connections {
            target: root
            function onActiveChanged() {
                credit.armed = false
            }
        }
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

            // Earned resets that clear the 5-hour and weekly limits at once.
            Column {
                readonly property var resets: card.reading ? card.reading.resets ?? null : null
                width: parent.width
                spacing: 10
                visible: !!resets && resets.available > 0

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.Colors.ring
                }
                Text {
                    text: parent.resets ? (parent.resets.available === 1 ? "1 limit reset" : parent.resets.available + " limit resets") : ""
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }
                Repeater {
                    model: parent.resets ? parent.resets.credits.length : 0

                    ResetCredit {
                        required property int index
                        entry: card.reading?.resets?.credits[index] ?? null
                        applicable: (card.reading?.resets?.applicable ?? 0) > 0
                    }
                }
                Text {
                    width: parent.width
                    visible: usage.resetOutcome.length > 0
                    text: usage.resetOutcome ? root.outcomeText(usage.resetOutcome) : ""
                    wrapMode: Text.WordWrap
                    color: usage.resetOutcome === "reset" ? Theme.Colors.success : Theme.Colors.warning
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
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
