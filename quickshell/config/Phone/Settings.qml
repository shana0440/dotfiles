import QtQuick
import Quickshell
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
