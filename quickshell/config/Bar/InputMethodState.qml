import QtQuick
import Quickshell.Services.SystemTray

// The current Fcitx input method, read from its tray icon.
QtObject {
    id: root

    // Fcitx publishes engine AND Mozc kana-mode changes through its tray icon.
    // Its tooltip title can be stale, so do not use it as the current state.
    readonly property var inputItem: SystemTray.items.values.find(item => item.id === "Fcitx") ?? null
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
}
