// Visual regression fixture: a transparent top bar with an exclusive zone.
// The transition must cover the wallpaper behind the whole reserved strip.
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 52
            exclusiveZone: 52
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "wallpaper-test-reserved-bar"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            Rectangle {
                x: 12; y: 10
                width: 240; height: 32; radius: 8
                color: "#121212"
                Text {
                    anchors.centerIn: parent
                    text: "Reserved top bar · 52px"
                    color: "white"
                    font.pixelSize: 14
                }
            }
        }
    }
}
