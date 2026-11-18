import QtQuick
import "../../Theme" as Theme
import "../../Services" as Services
import ".." as Phone

Page {
    id: settings

    property bool cleared: false
    signal openSchedules
    signal openCharacter

    title: "Settings"
    backLabel: "Chat"
    onActiveChanged: if (active) Services.Mei.loadSchedules()

    Column {
        width: parent.width
        spacing: 10 * settings.pt
        bottomPadding: 18 * settings.pt

        Phone.Avatar {
            id: profileAvatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96 * settings.pt
            height: width
            name: Services.Mei.name
            source: Services.Mei.avatar
            opacity: Services.Mei.choosingAvatar ? 0.5 : 1
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Mei.chooseAvatar()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Services.Mei.name
            color: Look.ink
            font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 24 * settings.pt }
        }
    }

    Group {
        pt: settings.pt
        ActionRow {
            pt: settings.pt
            icon: "screenshot"
            label: profileAvatar.hasPhoto ? "Change photo" : "Choose photo"
            onClicked: Services.Mei.chooseAvatar()
        }
        ActionRow {
            visible: Services.Mei.avatar !== ""
            pt: settings.pt
            separated: true
            icon: "remove"
            label: "Remove photo"
            tint: Look.destructive
            onClicked: Services.Mei.removeAvatar()
        }
    }

    Caption {
        visible: Services.Mei.avatarError !== ""
        pt: settings.pt
        note: true
        text: Services.Mei.avatarError
        color: Look.destructive
    }

    Item {
        visible: Services.Mei.avatarError === ""
        width: 1
        height: 12 * settings.pt
    }

    Group {
        pt: settings.pt
        NavRow {
            pt: settings.pt
            icon: "character"
            tile: Look.characterTile
            label: "CHARACTER.md"
            onClicked: settings.openCharacter()
        }
    }

    Caption { pt: settings.pt; note: true; text: "Her language, tone and speaking style." }

    Group {
        pt: settings.pt
        NavRow {
            pt: settings.pt
            icon: "schedules"
            tile: Look.schedulesTile
            label: "Schedules"
            detail: Services.Mei.schedules.length
            onClicked: settings.openSchedules()
        }
    }

    Caption { pt: settings.pt; note: true; text: "Jobs she runs on her own." }

    footer: [
        Group {
            pt: settings.pt
            ActionRow {
                id: resetRow
                pt: settings.pt
                icon: "reset"
                label: "Reset memory"
                tint: Look.destructive
                onClicked: resetAlert.open()
            }
        },
        Caption {
            pt: settings.pt
            text: settings.cleared ? Services.Mei.name + "'s memory and chat history are cleared."
                : "Forget everything " + Services.Mei.name + " remembers and delete the chat history."
        }
    ]

    overlays: Alert {
        id: resetAlert
        pt: settings.pt
        hiddenBottom: settings.hiddenBottom
        title: "Reset memory?"
        message: "This removes everything " + Services.Mei.name
            + " remembers, along with the chat history, session summaries and logs. It cannot be restored."
        confirmLabel: Services.Mei.resetting ? "Resetting…" : "Reset"
        busy: Services.Mei.resetting
        onDismissed: settings.focusPage()
        onConfirmed: {
            resetAlert.error = ""
            Services.Mei.resetMemory(failure => {
                resetAlert.error = failure
                if (failure) return
                settings.cleared = true
                resetAlert.close()
            })
        }
    }
}
