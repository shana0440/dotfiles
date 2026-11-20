import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme" as Theme

ShaderEffect {
    id: root

    required property Surface target
    property IslandGoo shaderSource: null
    property Item leading: null
    property Item trailing: null
    property Item leadingOuter: null
    property Item trailingOuter: null
    property real padding: 28
    readonly property bool ready: shaderFile !== "" && status !== ShaderEffect.Error
        && GraphicsInfo.api !== GraphicsInfo.Unknown && GraphicsInfo.api !== GraphicsInfo.Software
        && GraphicsInfo.api !== GraphicsInfo.Null

    readonly property string shaderFile: shaderSource ? shaderSource.shaderFile : shaderPath.text().trim()
    readonly property real islandLeft: target.x + (target.shift?.x ?? 0)
    readonly property real islandTop: target.y + (target.shift?.y ?? 0)
    readonly property var satellites: [leading, trailing, leadingOuter, trailingOuter].filter(item => item !== null)

    x: Math.min(islandLeft, ...satellites.map(item => item.x)) - padding
    y: Math.min(islandTop, ...satellites.map(item => item.y)) - padding
    width: Math.max(islandLeft + target.width, ...satellites.map(item => item.x + item.width)) + padding - x
    height: Math.max(islandTop + target.height, ...satellites.map(item => item.y + item.height)) + padding - y
    visible: ready && target.visible

    function circle(item) {
        return item ? Qt.vector4d(item.x + item.drift + item.width / 2 - x, item.y + item.height / 2 - y,
            item.diameter, item.blend) : Qt.vector4d(0, 0, 0, 0)
    }

    function centerAndPaintedSize(item) {
        return item ? Qt.vector4d(item.x + item.drift + item.width / 2 - x, item.y + item.height / 2 - y,
            item.paintedWidth, item.paintedHeight) : Qt.vector4d(0, 0, 0, 0)
    }

    property vector2d resolution: Qt.vector2d(width, height)
    property color fillColor: Theme.Colors.surfaceFill(target.clearness)
    property color ringColor: Theme.Colors.surfaceEdge(target.clearness)
    property color shadowColor: Theme.Colors.surfaceShadow(target.clearness)
    property vector4d island: Qt.vector4d(islandLeft - x, islandTop - y, target.width, target.height)
    property real islandRadius: target.radius
    property vector4d leftCircle: circle(leading)
    property vector4d rightCircle: circle(trailing)
    property vector4d leftOuter: centerAndPaintedSize(leadingOuter)
    property vector2d leftOuterShape: Qt.vector2d(leadingOuter?.paintedRadius ?? 0, leadingOuter?.blend ?? 0)
    property vector4d rightOuter: centerAndPaintedSize(trailingOuter)
    property vector2d rightOuterShape: Qt.vector2d(trailingOuter?.paintedRadius ?? 0, trailingOuter?.blend ?? 0)

    fragmentShader: shaderFile ? "file://" + shaderFile.split("/").map(encodeURIComponent).join("/") : ""

    FileView {
        id: shaderPath
        path: root.shaderSource ? "" : (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
            + "/quickshell-shaders/island-goo"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
}
