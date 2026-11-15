import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme" as Theme

ShaderEffect {
    id: root

    required property Item target
    required property Item leading
    required property Item trailing
    required property Item leadingOuter
    required property Item trailingOuter
    property real padding: 28
    readonly property bool ready: shaderFile !== "" && status === ShaderEffect.Compiled

    readonly property string shaderFile: shaderPath.text().trim()
    readonly property real islandLeft: target.x + target.shift.x
    readonly property real islandTop: target.y + target.shift.y

    x: Math.min(islandLeft, leading.x, leadingOuter.x) - padding
    y: Math.min(islandTop, leading.y, trailing.y, leadingOuter.y, trailingOuter.y) - padding
    width: Math.max(islandLeft + target.width, trailing.x + trailing.width, trailingOuter.x + trailingOuter.width)
        + padding - x
    height: Math.max(islandTop + target.height, leading.y + leading.height, trailing.y + trailing.height,
        leadingOuter.y + leadingOuter.height, trailingOuter.y + trailingOuter.height) + padding - y
    visible: shaderFile !== ""

    function circle(item) {
        return Qt.vector4d(item.x + item.drift + item.width / 2 - x, item.y + item.height / 2 - y,
            item.diameter, item.blend)
    }

    function centerAndPaintedSize(item) {
        return Qt.vector4d(item.x + item.drift + item.width / 2 - x, item.y + item.height / 2 - y,
            item.paintedWidth, item.paintedHeight)
    }

    property vector2d resolution: Qt.vector2d(width, height)
    property color fillColor: Theme.Colors.surfaceFill(Theme.Colors.centerClearness)
    property color ringColor: Theme.Colors.surfaceEdge(Theme.Colors.centerClearness)
    property color shadowColor: Theme.Colors.surfaceShadow(Theme.Colors.centerClearness)
    property vector4d island: Qt.vector4d(islandLeft - x, islandTop - y, target.width, target.height)
    property real islandRadius: target.radius
    property vector4d leftCircle: circle(leading)
    property vector4d rightCircle: circle(trailing)
    property vector4d leftOuter: centerAndPaintedSize(leadingOuter)
    property vector2d leftOuterShape: Qt.vector2d(leadingOuter.paintedRadius, leadingOuter.blend)
    property vector4d rightOuter: centerAndPaintedSize(trailingOuter)
    property vector2d rightOuterShape: Qt.vector2d(trailingOuter.paintedRadius, trailingOuter.blend)

    fragmentShader: shaderFile ? "file://" + shaderFile.split("/").map(encodeURIComponent).join("/") : ""

    FileView {
        id: shaderPath
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
            + "/quickshell-shaders/island-goo"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
}
