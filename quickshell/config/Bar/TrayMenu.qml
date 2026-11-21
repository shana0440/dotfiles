import QtQuick
import QtQuick.Effects
import Quickshell
import "../Theme" as Theme
import "../Components" as Components

PopupWindow {
    id: root

    property Item island: null
    property var trayItem: null
    property var submenus: []
    readonly property var currentMenu: submenus.length > 0 ? submenus[submenus.length - 1] : trayItem?.menu ?? null
    readonly property int shadowMargin: 16
    readonly property int gap: 8
    property real maxListHeight: 600
    readonly property bool hovered: visible && menuHover.hovered

    function open(item) {
        trayItem = item
        submenus = []
        visible = true
    }

    function close() {
        visible = false
    }

    function back() {
        if (submenus.length > 0)
            submenus = submenus.slice(0, -1)
        else
            close()
    }

    function choose(entry) {
        if (!entry.enabled)
            return
        if (entry.hasChildren) {
            submenus = submenus.concat([entry])
            return
        }
        entry.triggered()
        close()
    }

    onVisibleChanged: {
        if (visible)
            keys.forceActiveFocus()
        else
            submenus = []
    }

    anchor.item: island
    anchor.rect.x: island ? island.width + shadowMargin : 0
    anchor.rect.y: island ? island.height + gap - shadowMargin : 0
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Left
    grabFocus: true
    color: Theme.Colors.transparent
    implicitWidth: panel.width + shadowMargin * 2
    implicitHeight: panel.height + shadowMargin * 2

    QsMenuOpener {
        menu: root.visible ? root.trayItem?.menu ?? null : null
    }

    QsMenuOpener {
        id: opener
        menu: root.currentMenu
    }

    Rectangle {
        id: panel
        x: root.shadowMargin
        y: root.shadowMargin
        width: 240
        height: Math.min(list.height, root.maxListHeight) + 12
        clip: true
        radius: 12
        color: Theme.Colors.panel
        border.width: 1
        border.color: Theme.Colors.edge

        HoverHandler { id: menuHover }

        RectangularShadow {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            offset.y: 4
            blur: 12
            spread: -4
            color: Theme.Colors.shadow
        }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: root.close()
            Keys.onLeftPressed: root.back()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Backspace) {
                    root.back()
                    event.accepted = true
                }
            }
        }

        Flickable {
            id: menuScroll
            x: 6
            y: 6
            width: parent.width - 12
            height: parent.height - 12
            contentHeight: list.height
            boundsBehavior: Flickable.StopAtBounds
            interactive: false

            Components.KineticScroll {
                view: menuScroll
            }

            Column {
                id: list
                width: parent.width

                MenuRow {
                    visible: root.submenus.length > 0
                    text: root.submenus[root.submenus.length - 1]?.text.replace(/_(?!_)/g, "") ?? ""
                    leadingAction: "back"
                    onChosen: root.back()
                }

                Rectangle {
                    visible: root.submenus.length > 0
                    width: parent.width
                    height: 9
                    color: Theme.Colors.transparent
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        height: 1
                        color: Theme.Colors.highlight
                    }
                }

                Repeater {
                    model: opener.children

                    Item {
                        id: entryItem
                        required property QsMenuEntry modelData
                        width: list.width
                        height: modelData.isSeparator ? 9 : row.height

                        Rectangle {
                            visible: entryItem.modelData.isSeparator
                            anchors.centerIn: parent
                            width: parent.width - 12
                            height: 1
                            color: Theme.Colors.highlight
                        }

                        MenuRow {
                            id: row
                            visible: !entryItem.modelData.isSeparator
                            width: parent.width
                            text: entryItem.modelData.text.replace(/_(?!_)/g, "")
                            enabled: entryItem.modelData.enabled
                            checked: entryItem.modelData.buttonType !== QsMenuButtonType.None
                                && entryItem.modelData.checkState === Qt.Checked
                            trailingAction: entryItem.modelData.hasChildren ? "forward" : ""
                            onChosen: root.choose(entryItem.modelData)
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: menuRow

        property string text: ""
        property string leadingAction: ""
        property string trailingAction: ""
        property bool checked: false
        signal chosen()

        width: list.width
        height: 30
        radius: 6
        opacity: enabled ? 1 : 0.4
        color: rowMouse.containsMouse && enabled ? Theme.Colors.highlight : Theme.Colors.transparent

        Components.Icon {
            id: leadingIcon
            visible: menuRow.leadingAction !== ""
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            action: menuRow.leadingAction || "back"
            iconColor: Theme.Colors.muted
        }

        Text {
            anchors.left: leadingIcon.visible ? leadingIcon.right : parent.left
            anchors.leftMargin: 8
            anchors.right: trailingIcon.visible ? trailingIcon.left : parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: menuRow.text
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: menuRow.leadingAction ? Theme.Colors.muted : Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 13
        }

        Components.Icon {
            id: trailingIcon
            visible: menuRow.checked || menuRow.trailingAction !== ""
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            action: menuRow.checked ? "check" : menuRow.trailingAction || "forward"
            iconColor: menuRow.checked ? Theme.Colors.foreground : Theme.Colors.muted
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: menuRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (menuRow.enabled) menuRow.chosen()
        }
    }
}
