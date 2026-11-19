import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    property bool active: false
    property var inputItem: null
    readonly property bool available: inputItem?.hasMenu === true
    readonly property bool japanese: Services.InputMethod.icon.startsWith("fcitx_mozc")
    property var inputEntries: inputMenu.children.values.filter(entry => entry.buttonType === QsMenuButtonType.RadioButton)
    readonly property var mozcMenu: inputMenu.children.values.find(entry => entry.icon.endsWith("/fcitx_mozc_tool")) ?? null
    property var modeEntries: kanaMenu.children.values.filter(entry =>
        entry.icon.endsWith("/fcitx_mozc_hiragana") || entry.icon.endsWith("/fcitx_mozc_katakana_full"))
    readonly property bool showKanaModes: japanese
    property int cursor: -1
    readonly property bool backPointed: cursor === 0
    readonly property int stopCount: 1 + inputRepeater.count + (showKanaModes ? kanaRepeater.count : 0)
    signal backRequested()
    readonly property var keyBindings: [
        { name: "Escape", key: "Escape", call: "close" },
        { name: "Tab", key: "Tab", call: "next" },
        { name: "ShiftTab", key: "SHIFT + Tab", call: "previous" },
        { name: "Return", key: "Return", call: "activate" },
        { name: "Space", key: "space", call: "activate" }
    ]

    function choiceAt(stop) {
        const index = stop - 1
        return index < inputRepeater.count ? inputRepeater.itemAt(index) : kanaRepeater.itemAt(index - inputRepeater.count)
    }

    function step(direction) {
        let stop = cursor
        for (let tried = 0; tried < stopCount; tried++) {
            stop = stop < 0 && direction < 0 ? stopCount - 1 : (stop + direction + stopCount) % stopCount
            if (stop === 0 || choiceAt(stop)?.enabled) {
                cursor = stop
                return
            }
        }
    }

    function activateCursor() {
        if (backPointed) {
            backRequested()
            return
        }
        const choice = cursor > 0 ? choiceAt(cursor) : null
        if (choice?.enabled)
            choice.activate()
    }

    Connections {
        target: Services.InputMethod
        enabled: root.active
        function onPickerStepped(direction) { root.step(direction) }
        function onPickerActivated() { root.activateCursor() }
    }

    implicitHeight: content.implicitHeight

    function bindingsScript(enabled) {
        return keyBindings.map(binding => {
            const handle = "qsInputMenu" + binding.name
            const command = "quickshell --path " + Quickshell.shellDir + " ipc call inputMenu " + binding.call
            return (enabled ? "if not " + handle + " then " + handle + " = hl.bind('" + binding.key
                    + "', hl.dsp.exec_cmd('" + command + "')) end; " : "")
                + "if " + handle + " then " + handle + ":set_enabled(" + enabled + ") end"
        }).join("; ")
    }

    function syncKeyBindings() {
        if (keyBindingSync.running)
            return
        keyBindingSync.requestedActive = root.active
        keyBindingSync.command = ["hyprctl", "eval", bindingsScript(root.active)]
        keyBindingSync.running = true
    }

    onActiveChanged: {
        cursor = -1
        syncKeyBindings()
    }
    Component.onCompleted: syncKeyBindings()
    Component.onDestruction: Quickshell.execDetached(["hyprctl", "eval", bindingsScript(false)])

    Process {
        id: keyBindingSync
        property bool requestedActive: false
        onExited: {
            if (requestedActive !== root.active)
                root.syncKeyBindings()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.syncKeyBindings()
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
        property string methodName: ""
        property bool selected: entry?.checkState === Qt.Checked
        property int cursorIndex: -1
        readonly property bool pointed: cursorIndex >= 0 && root.cursor === cursorIndex
        signal activated()

        function activate() {
            if (methodName)
                Services.InputMethod.select(methodName)
            else {
                entry.triggered()
                activated()
            }
        }
        width: content.width
        height: 40
        radius: 8
        enabled: root.available && (entry?.enabled ?? false)
        opacity: enabled ? 1 : 0.4
        color: selected || mouse.containsMouse || activeFocus || pointed
            ? Theme.Colors.highlight : Theme.Colors.transparent
        border.width: pointed ? 2 : 0
        border.color: Theme.Colors.muted
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: description
        Keys.onReturnPressed: activate()
        Keys.onSpacePressed: activate()

        Text {
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
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
        Components.Icon {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            action: "check"
            visible: !choice.compact && choice.selected
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.activate()
        }
        Components.Tooltip {
            text: choice.description
            shown: choice.compact && (mouse.containsMouse || choice.activeFocus || choice.pointed)
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: 2

        Text {
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            width: parent.width
            visible: !root.available || root.inputEntries.length === 0
            text: !root.inputItem ? "Fcitx5 unavailable" : !root.available ? "Input menu unavailable" : "Loading input methods…"
            textFormat: Text.PlainText
            color: Theme.Colors.muted
            font.pixelSize: 13
            topPadding: 10
        }

        Repeater {
            id: inputRepeater
            model: root.inputEntries
            Choice {
                required property var modelData
                required property int index
                cursorIndex: 1 + index
                entry: modelData
                methodName: Services.InputMethod.order[index] ?? ""
                selected: Services.InputMethod.name === methodName
            }
        }

        Text {
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            visible: root.showKanaModes
            text: "Japanese mode"
            color: Theme.Colors.muted
            font.pixelSize: 12
            topPadding: 10
            bottomPadding: 4
        }

        Row {
            width: parent.width
            spacing: 6
            visible: root.showKanaModes
            Repeater {
                id: kanaRepeater
                model: [
                    { icon: "fcitx_mozc_hiragana", label: "あ", description: "Hiragana" },
                    { icon: "fcitx_mozc_katakana_full", label: "ア", description: "Katakana" }
                ]
                Choice {
                    required property var modelData
                    required property int index
                    width: (content.width - 6) / 2
                    cursorIndex: 1 + inputRepeater.count + index
                    entry: root.modeEntries.find(entry => entry.icon.endsWith("/" + modelData.icon)) ?? null
                    label: modelData.label
                    description: modelData.description
                    compact: true
                    selected: Services.InputMethod.icon === modelData.icon
                    onActivated: Services.InputMethod.selected("mozc", modelData.icon)
                }
            }
        }
    }
}
