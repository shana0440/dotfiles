import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Theme" as Theme
import "../Components" as Components

Item {
    id: root
    objectName: "inputMethodMenu"

    property bool active: false
    property var inputItem: null
    property string currentDescription: ""
    readonly property bool available: inputItem?.hasMenu === true
    readonly property bool japanese: inputItem?.icon.startsWith("image://icon/fcitx_mozc") === true
    // Keep Fcitx as the only writer of input state; these are its live menu actions.
    property var inputEntries: inputMenu.children.values.filter(entry => entry.buttonType === QsMenuButtonType.RadioButton)
    readonly property var mozcMenu: inputMenu.children.values.find(entry => entry.icon.endsWith("/fcitx_mozc_tool")) ?? null
    property var modeEntries: kanaMenu.children.values.filter(entry =>
        entry.icon.endsWith("/fcitx_mozc_hiragana") || entry.icon.endsWith("/fcitx_mozc_katakana_full"))
    // Visibility follows the selected engine, not editor-specific action availability.
    readonly property bool showKanaModes: japanese
    readonly property bool kanaActionsAvailable: modeEntries.length === 2 && modeEntries.every(entry => entry.enabled)
    signal closeRequested()

    implicitWidth: 340
    implicitHeight: content.implicitHeight + 24
    focus: active
    Keys.onEscapePressed: closeRequested()

    // The editor must retain its input context for Fcitx's native actions.
    // Intercept Escape in Hyprland only while this non-focusable menu is open.
    function syncEscapeBinding() {
        if (escapeBinding.running)
            return
        escapeBinding.requestedActive = root.active
        escapeBinding.command = ["hyprctl", "eval",
            "if not qsInputMenuEscape then "
            + "qsInputMenuEscape = hl.bind('Escape', hl.dsp.exec_cmd('quickshell ipc call inputMenu close')) end; "
            + "qsInputMenuEscape:set_enabled(" + (root.active ? "true" : "false") + ")"]
        escapeBinding.running = true
    }

    onActiveChanged: syncEscapeBinding()
    Component.onCompleted: syncEscapeBinding()
    Component.onDestruction: Quickshell.execDetached(["hyprctl", "eval",
        "if qsInputMenuEscape then qsInputMenuEscape:set_enabled(false) end"])

    Process {
        id: escapeBinding
        property bool requestedActive: false
        onExited: {
            if (requestedActive !== root.active)
                root.syncEscapeBinding()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.syncEscapeBinding()
        }
    }

    QsMenuOpener {
        id: inputMenu
        menu: root.active && root.available ? root.inputItem.menu : null
    }
    QsMenuOpener {
        id: kanaMenu
        menu: root.active ? root.mozcMenu : null
    }

    component Choice: Rectangle {
        id: choice
        required property var entry
        property string label: entry?.text ?? ""
        property string description: entry?.text ?? label
        property bool compact: false
        width: content.width
        height: 38
        radius: 6
        enabled: root.available && (entry?.enabled ?? false)
        opacity: enabled ? 1 : 0.4
        color: entry?.checkState === Qt.Checked || mouse.containsMouse || activeFocus
            ? Theme.Colors.highlight : Theme.Colors.transparent
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: description
        Keys.onReturnPressed: entry.triggered()
        Keys.onSpacePressed: entry.triggered()

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40
            text: choice.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            horizontalAlignment: choice.compact ? Text.AlignHCenter : Text.AlignLeft
            color: Theme.Colors.foreground
            font.pixelSize: choice.compact ? 20 : 14
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "✓"
            visible: choice.entry?.checkState === Qt.Checked
            color: Theme.Colors.foreground
            font.pixelSize: 14
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.entry.triggered()
        }
        Components.Tooltip {
            text: choice.description
            shown: choice.compact && (mouse.containsMouse || choice.activeFocus)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.Colors.background
        radius: 8
        MouseArea { anchors.fill: parent }
    }

    Column {
        id: content
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 6

        Row {
            width: parent.width
            height: 30
            Text {
                width: parent.width - closeButton.width
                height: parent.height
                text: "Input method"
                color: Theme.Colors.foreground
                font.pixelSize: 16
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }
            Components.IconButton {
                id: closeButton
                objectName: "closeInputMenu"
                width: 28
                height: 28
                icon: "close"
                tooltip: "Close input menu"
                onClicked: root.closeRequested()
            }
        }

        Text {
            width: parent.width
            text: root.currentDescription
            textFormat: Text.PlainText
            color: Theme.Colors.foreground
            opacity: 0.65
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: !root.available || root.inputEntries.length === 0
            text: !root.inputItem ? "Fcitx5 unavailable" : !root.available ? "Input menu unavailable" : "Loading input methods…"
            textFormat: Text.PlainText
            color: Theme.Colors.foreground
            font.pixelSize: 13
        }

        Repeater {
            model: root.inputEntries
            Choice {
                required property var modelData
                required property int index
                objectName: "inputChoice-" + index
                entry: modelData
            }
        }

        Text {
            visible: root.showKanaModes
            text: "Japanese mode"
            color: Theme.Colors.foreground
            opacity: 0.65
            font.pixelSize: 12
            topPadding: 6
        }

        Row {
            width: parent.width
            spacing: 6
            visible: root.showKanaModes
            Repeater {
                model: [
                    { icon: "fcitx_mozc_hiragana", label: "あ", description: "Hiragana" },
                    { icon: "fcitx_mozc_katakana_full", label: "ア", description: "Katakana" }
                ]
                Choice {
                    required property var modelData
                    required property int index
                    objectName: "kanaChoice-" + index
                    width: (content.width - 6) / 2
                    entry: root.modeEntries.find(entry => entry.icon.endsWith("/" + modelData.icon)) ?? null
                    label: modelData.label
                    description: modelData.description
                    compact: true
                }
            }
        }
    }
}
