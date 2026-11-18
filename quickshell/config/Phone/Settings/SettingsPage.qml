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
        bottomPadding: 16 * settings.pt

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

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24 * settings.pt
            TextButton {
                pt: settings.pt
                label: profileAvatar.hasPhoto ? "Change photo" : "Choose photo"
                onClicked: Services.Mei.chooseAvatar()
            }
            TextButton {
                visible: Services.Mei.avatar !== ""
                pt: settings.pt
                label: "Remove photo"
                tint: Look.destructive
                onClicked: Services.Mei.removeAvatar()
            }
        }
    }

    Group {
        pt: settings.pt
        NavRow {
            pt: settings.pt
            label: "CHARACTER.md"
            onClicked: settings.openCharacter()
        }
        NavRow {
            pt: settings.pt
            separated: true
            label: "Schedules"
            detail: Services.Mei.schedules.length
            onClicked: settings.openSchedules()
        }
    }

    Caption { pt: settings.pt; note: true; text: "CHARACTER.md sets " + Services.Mei.name + "'s name, language and tone. Schedules are the jobs she runs on her own." }

    footer: [
        Group {
            pt: settings.pt
            MouseArea {
                id: resetRow
                width: parent.width
                height: 44 * settings.pt
                cursorShape: Qt.PointingHandCursor
                onClicked: resetAlert.open()
                Rectangle {
                    anchors.fill: parent
                    color: resetRow.pressed ? Look.pressedFill : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    text: "Reset memory"
                    color: Look.destructive
                    font { family: Theme.Fonts.family; pixelSize: 17 * settings.pt }
                }
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
