import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../Theme" as Theme
import "../Components" as Components

Rectangle {
    id: root

    // Fcitx publishes engine AND Mozc kana-mode changes through its tray icon.
    // Its tooltip title can be stale, so do not use it as the current state.
    property var inputItem: SystemTray.items.values.find(item => item.id === "Fcitx") ?? null
    signal clicked()
    readonly property var states: ({
        "input-keyboard-symbolic": ["EN", "English"],
        "input-keyboard": ["EN", "English"],
        "fcitx_mozc": ["日", "Japanese"],
        "fcitx_mozc_hiragana": ["あ", "Japanese · Hiragana"],
        "fcitx_mozc_katakana_full": ["ア", "Japanese · Katakana"],
        "fcitx_mozc_katakana_half": ["ｱ", "Japanese · Half-width Katakana"],
        "fcitx_mozc_alpha_full": ["Ａ", "Japanese · Full-width Latin"],
        "fcitx_mozc_alpha_half": ["A", "Japanese · Latin"],
        "fcitx_mozc_direct": ["A", "Japanese · Direct input"],
        "fcitx-chewing": ["注音", "Traditional Chinese · Zhuyin"]
    })
    readonly property var stateInfo: states[inputItem?.icon.replace("image://icon/", "") ?? ""] ?? null
    readonly property string label: !inputItem ? "IM?" : stateInfo?.[0] ?? "IM"
    readonly property string description: !inputItem ? "Fcitx5 unavailable" : stateInfo?.[1] ?? "Input method"

    width: Math.max(40, inputLabel.implicitWidth + 16)
    height: 32
    radius: height / 2
    color: mouse.containsMouse || activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
    opacity: inputItem ? 1 : 0.5
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: description + "; input method menu"
    Keys.onReturnPressed: openMenu()
    Keys.onSpacePressed: openMenu()

    function openMenu() {
        clicked()
    }

    Text {
        id: inputLabel
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        anchors.centerIn: parent
        text: root.label
        textFormat: Text.PlainText
        color: Theme.Colors.foreground
        font.pixelSize: 14
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openMenu()
    }

    Components.Tooltip {
        text: root.description + (root.inputItem?.hasMenu ? " · Click for input and kana modes" : "")
        shown: mouse.containsMouse || root.activeFocus
        alignment: Qt.AlignRight
    }
}
