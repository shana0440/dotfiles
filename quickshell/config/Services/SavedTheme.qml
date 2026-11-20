import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme" as Theme

Scope {
    FileView {
        path: Quickshell.statePath("theme.json")
        blockLoading: true
        watchChanges: false
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: Theme.Colors.theme = settings.theme === "transparent" ? "transparent" : "dark"

        JsonAdapter {
            id: settings
            property string theme: "dark"
        }
    }

    IpcHandler {
        target: "theme"
        function set(name: string): string {
            if (name !== "dark" && name !== "transparent") return "theme is dark or transparent"
            Theme.Colors.theme = name
            return name
        }
        function state(): string { return Theme.Colors.theme }
    }

    Connections {
        target: Theme.Colors
        function onThemeChanged() { settings.theme = Theme.Colors.theme }
    }
}
