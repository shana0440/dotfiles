import QtQuick
import Quickshell
import Quickshell.Widgets
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: settings

    property bool active: false
    property real hiddenBottom: 0
    readonly property real pt: width / 390
    readonly property color ink: "#000000"
    readonly property color secondaryInk: "#8e8e93"
    readonly property color accent: "#007aff"
    readonly property color destructive: "#ff3b30"
    readonly property color barFill: "#f6f6f6"
    readonly property color hairline: "#c8c7cc"
    readonly property color pageFill: "#f2f2f7"
    signal back

    function focusPage() { page.forceActiveFocus() }

    Rectangle {
        anchors.fill: parent
        color: settings.pageFill
    }

    Flickable {
        id: page
        anchors { top: header.bottom; bottom: parent.bottom; bottomMargin: settings.hiddenBottom; left: parent.left; right: parent.right }
        contentHeight: sections.height + 32 * settings.pt
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Keys.onEscapePressed: settings.back()

        MouseArea {
            width: page.width
            height: Math.max(page.height, page.contentHeight)
            onClicked: page.forceActiveFocus()
        }

        Column {
            id: sections
            y: 24 * settings.pt
            width: page.width
            spacing: 8 * settings.pt

            Column {
                width: parent.width
                spacing: 10 * settings.pt
                bottomPadding: 16 * settings.pt

                Avatar {
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

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 24 * settings.pt
                    TextButton {
                        label: profileAvatar.hasPhoto ? "Change photo" : "Choose photo"
                        onClicked: Services.Mei.chooseAvatar()
                    }
                    TextButton {
                        visible: Services.Mei.avatar !== ""
                        label: "Remove photo"
                        tint: settings.destructive
                        onClicked: Services.Mei.removeAvatar()
                    }
                }
            }

            SectionLabel { text: "Name" }

            Group {
                Item {
                    width: parent.width
                    height: 44 * settings.pt
                    TextInput {
                        id: nameField
                        anchors { left: parent.left; right: parent.right; leftMargin: 16 * settings.pt; rightMargin: 16 * settings.pt; verticalCenter: parent.verticalCenter }
                        text: Services.Mei.name
                        color: settings.ink
                        selectionColor: Qt.alpha(settings.accent, 0.3)
                        selectedTextColor: settings.ink
                        selectByMouse: true
                        maximumLength: 40
                        font { family: Theme.Fonts.family; pixelSize: 17 * settings.pt }
                        onEditingFinished: {
                            Services.Mei.rename(text)
                            text = Qt.binding(() => Services.Mei.name)
                        }
                        onAccepted: page.forceActiveFocus()
                        Keys.onEscapePressed: {
                            text = Qt.binding(() => Services.Mei.name)
                            page.forceActiveFocus()
                        }
                    }
                }
            }

            SectionNote { text: "Saved to CHARACTER.md in mei's home, so she answers to it too." }

            SectionLabel { text: "Schedules" }

            Group {
                Repeater {
                    model: Services.Mei.schedules
                    ScheduleRow {}
                }
                Text {
                    visible: Services.Mei.schedules.length === 0
                    width: parent.width
                    height: 44 * settings.pt
                    leftPadding: 16 * settings.pt
                    verticalAlignment: Text.AlignVCenter
                    text: "No schedules"
                    color: settings.secondaryInk
                    font { family: Theme.Fonts.family; pixelSize: 17 * settings.pt }
                }
            }

            SectionNote {
                text: Services.Mei.scheduleError || "A turned-off schedule stays in config.toml but never runs on its own. Removing one keeps its script or prompt."
                color: Services.Mei.scheduleError ? settings.destructive : settings.secondaryInk
            }

            Group {
                MouseArea {
                    id: resetRow
                    width: parent.width
                    height: 44 * settings.pt
                    cursorShape: Qt.PointingHandCursor
                    onClicked: resetDialog.open()
                    Rectangle {
                        anchors.fill: parent
                        radius: 10 * settings.pt
                        color: resetRow.pressed ? "#e5e5ea" : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "Reset memory"
                        color: settings.destructive
                        font { family: Theme.Fonts.family; pixelSize: 17 * settings.pt }
                    }
                }
            }

            SectionNote {
                text: resetDialog.cleared ? Services.Mei.name + "'s memory and chat history are cleared."
                    : "Forget everything " + Services.Mei.name + " remembers and delete the chat history."
            }
        }
    }

    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 104 * settings.pt
        color: Qt.alpha(settings.barFill, 0.96)

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: settings.hairline
        }

        StatusBar {
            id: statusBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 54 * settings.pt
            pt: settings.pt
            active: settings.active
            ink: settings.ink
        }

        MouseArea {
            id: backButton
            anchors { left: parent.left; leftMargin: 6 * settings.pt; top: statusBar.bottom; topMargin: 12 * settings.pt }
            width: backLabel.width
            height: backLabel.height
            cursorShape: Qt.PointingHandCursor
            onClicked: settings.back()

            Row {
                id: backLabel
                opacity: backButton.pressed ? 0.4 : 1
                spacing: 2 * settings.pt
                Components.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26 * settings.pt
                    height: width
                    action: "back"
                    iconColor: settings.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Chat"
                    color: settings.accent
                    font { family: Theme.Fonts.family; pixelSize: 17 * settings.pt }
                }
            }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: backButton.verticalCenter }
            text: "Settings"
            color: settings.ink
            font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 17 * settings.pt }
        }
    }

    onActiveChanged: if (active) Services.Mei.loadSchedules()

    MouseArea {
        id: resetDialog
        property bool shown: false
        property bool cleared: false
        property string error: ""

        function open() {
            error = ""
            shown = true
            forceActiveFocus()
        }
        function dismiss() {
            if (Services.Mei.resetting) return
            shown = false
            page.forceActiveFocus()
        }
        function confirm() {
            error = ""
            Services.Mei.resetMemory(failure => {
                error = failure
                if (failure) return
                cleared = true
                dismiss()
            })
        }

        anchors.fill: parent
        z: 1
        visible: opacity > 0
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        onClicked: {}
        Keys.onEscapePressed: dismiss()
        Keys.onReturnPressed: confirm()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.4)
        }

        ClippingRectangle {
            id: alert
            anchors { centerIn: parent; verticalCenterOffset: -settings.hiddenBottom / 2 }
            width: 270 * settings.pt
            height: alertText.height + alertButtons.height
            radius: 14 * settings.pt
            color: Qt.rgba(0.96, 0.96, 0.96, 0.98)
            scale: resetDialog.shown ? 1 : 1.15
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Column {
                id: alertText
                width: parent.width
                topPadding: 19 * settings.pt
                bottomPadding: 19 * settings.pt
                spacing: 4 * settings.pt
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Reset memory?"
                    color: settings.ink
                    font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 17 * settings.pt }
                }
                Text {
                    x: 16 * settings.pt
                    width: parent.width - 2 * x
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "This removes everything " + Services.Mei.name
                        + " remembers, along with the chat history, session summaries and logs. It cannot be restored."
                    color: settings.ink
                    font { family: Theme.Fonts.family; pixelSize: 13 * settings.pt }
                }
                Text {
                    visible: resetDialog.error !== ""
                    x: 16 * settings.pt
                    width: parent.width - 2 * x
                    topPadding: 4 * settings.pt
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: resetDialog.error
                    color: settings.destructive
                    font { family: Theme.Fonts.family; pixelSize: 13 * settings.pt }
                }
            }

            Rectangle {
                anchors.bottom: alertButtons.top
                width: parent.width
                height: 1
                color: settings.hairline
            }

            Row {
                id: alertButtons
                anchors.bottom: parent.bottom
                width: parent.width
                height: 44 * settings.pt
                AlertButton {
                    label: "Cancel"
                    bold: true
                    onClicked: resetDialog.dismiss()
                }
                Rectangle {
                    width: 1
                    height: parent.height
                    color: settings.hairline
                }
                AlertButton {
                    label: Services.Mei.resetting ? "Resetting…" : "Reset"
                    tint: settings.destructive
                    onClicked: resetDialog.confirm()
                }
            }
        }
    }

    component AlertButton: MouseArea {
        id: alertButton
        property string label
        property color tint: settings.accent
        property bool bold: false
        width: (parent.width - 1) / 2
        height: parent.height
        enabled: !Services.Mei.resetting
        cursorShape: Qt.PointingHandCursor
        Rectangle {
            anchors.fill: parent
            color: alertButton.pressed ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
        }
        Text {
            anchors.centerIn: parent
            text: alertButton.label
            color: alertButton.tint
            opacity: alertButton.enabled ? 1 : 0.5
            font { family: Theme.Fonts.family; weight: alertButton.bold ? Font.DemiBold : Font.Normal; pixelSize: 17 * settings.pt }
        }
    }

    function nextRun(ms) {
        const due = new Date(ms)
        const today = new Date().toDateString() === due.toDateString()
        return Qt.formatDateTime(due, today ? "hh:mm" : "ddd hh:mm")
    }

    component ScheduleRow: Item {
        id: scheduleRow
        required property var modelData
        required property int index
        readonly property bool changing: Services.Mei.changingSchedule === modelData.name
        readonly property string when: modelData.spec.daily_at !== undefined
            ? "Daily at " + modelData.spec.daily_at
            : modelData.spec.every_minutes === 1 ? "Every minute" : "Every " + modelData.spec.every_minutes + " minutes"
        property bool wanted: modelData.enabled
        property bool confirming: false
        width: parent.width
        height: 60 * settings.pt

        Rectangle {
            visible: scheduleRow.index > 0
            anchors { top: parent.top; left: parent.left; leftMargin: 16 * settings.pt; right: parent.right }
            height: 1
            color: settings.hairline
        }

        Column {
            anchors { left: parent.left; leftMargin: 16 * settings.pt; right: controls.left; rightMargin: 12 * settings.pt; verticalCenter: parent.verticalCenter }
            spacing: 2 * settings.pt
            Text {
                width: parent.width
                text: scheduleRow.modelData.name
                elide: Text.ElideRight
                color: settings.ink
                font { family: Theme.Fonts.family; pixelSize: 17 * settings.pt }
            }
            Text {
                width: parent.width
                text: scheduleRow.when + (scheduleRow.modelData.enabled && scheduleRow.modelData.dueAt
                    ? " · next " + settings.nextRun(scheduleRow.modelData.dueAt) : "")
                elide: Text.ElideRight
                color: settings.secondaryInk
                font { family: Theme.Fonts.family; pixelSize: 13 * settings.pt }
            }
        }

        Row {
            id: controls
            anchors { right: parent.right; rightMargin: 12 * settings.pt; verticalCenter: parent.verticalCenter }
            spacing: 14 * settings.pt

            Toggle {
                visible: !scheduleRow.confirming
                anchors.verticalCenter: parent.verticalCenter
                on: scheduleRow.changing ? scheduleRow.wanted : scheduleRow.modelData.enabled
                busy: Services.Mei.changingSchedule !== ""
                onToggled: {
                    scheduleRow.wanted = !scheduleRow.modelData.enabled
                    Services.Mei.changeSchedule(scheduleRow.wanted ? "enable" : "disable", scheduleRow.modelData.name)
                }
            }

            MouseArea {
                visible: !scheduleRow.confirming
                anchors.verticalCenter: parent.verticalCenter
                width: 26 * settings.pt
                height: width
                enabled: Services.Mei.changingSchedule === ""
                cursorShape: Qt.PointingHandCursor
                onClicked: scheduleRow.confirming = true
                Components.Icon {
                    anchors.centerIn: parent
                    width: 22 * settings.pt
                    height: width
                    action: "remove"
                    iconColor: parent.pressed ? settings.hairline : settings.secondaryInk
                }
            }

            TextButton {
                visible: scheduleRow.confirming
                anchors.verticalCenter: parent.verticalCenter
                label: "Cancel"
                onClicked: scheduleRow.confirming = false
            }

            Rectangle {
                visible: scheduleRow.confirming
                anchors.verticalCenter: parent.verticalCenter
                width: removeLabel.width + 24 * settings.pt
                height: 32 * settings.pt
                radius: height / 2
                color: removeArea.pressed ? Qt.darker(settings.destructive, 1.15) : settings.destructive
                Text {
                    id: removeLabel
                    anchors.centerIn: parent
                    text: scheduleRow.changing ? "Removing…" : "Remove"
                    color: "white"
                    font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 15 * settings.pt }
                }
                MouseArea {
                    id: removeArea
                    anchors.fill: parent
                    enabled: Services.Mei.changingSchedule === ""
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Mei.changeSchedule("remove", scheduleRow.modelData.name)
                }
            }
        }
    }

    component Toggle: MouseArea {
        id: toggle
        property bool on: false
        property bool busy: false
        signal toggled
        width: 51 * settings.pt
        height: 31 * settings.pt
        enabled: !busy
        cursorShape: Qt.PointingHandCursor
        onClicked: toggled()

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: toggle.on ? "#34c759" : "#e9e9ea"
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        Rectangle {
            readonly property real inset: 2 * settings.pt
            x: toggle.on ? toggle.width - width - inset : inset
            y: inset
            width: toggle.height - 2 * inset
            height: width
            radius: width / 2
            color: "white"
            border { width: 0.5; color: Qt.rgba(0, 0, 0, 0.04) }
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        }
    }

    component SectionLabel: Text {
        x: 32 * settings.pt
        width: parent.width - 2 * x
        color: settings.secondaryInk
        font { family: Theme.Fonts.family; pixelSize: 13 * settings.pt }
    }

    component SectionNote: Text {
        x: 32 * settings.pt
        width: parent.width - 2 * x
        bottomPadding: 20 * settings.pt
        wrapMode: Text.Wrap
        color: settings.secondaryInk
        font { family: Theme.Fonts.family; pixelSize: 13 * settings.pt }
    }

    component Group: Rectangle {
        default property alias rows: rowColumn.data
        x: 16 * settings.pt
        width: parent.width - 2 * x
        height: rowColumn.height
        radius: 10 * settings.pt
        color: "white"
        Column {
            id: rowColumn
            width: parent.width
        }
    }

    component TextButton: Text {
        id: button
        property string label
        property color tint: settings.accent
        signal clicked
        text: label
        color: tint
        opacity: buttonArea.pressed ? 0.4 : 1
        font { family: Theme.Fonts.family; pixelSize: 15 * settings.pt }
        MouseArea {
            id: buttonArea
            anchors.fill: parent
            anchors.margins: -6 * settings.pt
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
