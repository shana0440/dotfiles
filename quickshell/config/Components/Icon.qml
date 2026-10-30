import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme" as Theme

Item {
    id: root

    property string action: "poweroff"
    property color iconColor: Theme.Colors.foreground
    readonly property string iconName: ({
        lock: "lock-keyhole",
        logout: "log-out",
        reboot: "rotate-cw",
        poweroff: "power"
    })[action] ?? "power"

    implicitWidth: 20
    implicitHeight: 20

    FileView {
        id: svg
        path: Quickshell.shellPath("Icons/lucide/" + root.iconName + ".svg")
        blockLoading: true
    }

    Image {
        anchors.fill: parent
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        // SVG currentColor does not inherit QML colors; apply it before rendering.
        source: "data:image/svg+xml;charset=utf-8," + encodeURIComponent(
            svg.text().replace(/currentColor/g, root.iconColor.toString()))
    }
}
