import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme" as Theme

// Paints an island and its two side circles as one liquid surface: a signed
// distance field with a smooth union, so a circle leaving or entering the island
// pulls a neck of the surface with it until it pinches off. While the shader is
// unavailable the surfaces paint themselves (see `ready`).
ShaderEffect {
    id: root

    // Siblings of this item: an Island and two MergeableCircles beside it.
    required property Item target
    required property Item leading
    required property Item trailing
    // Room for the drop shadow around the shapes.
    property real padding: 28
    readonly property bool ready: shaderFile !== "" && status === ShaderEffect.Compiled

    readonly property string shaderFile: shaderPath.text().trim()
    readonly property real islandLeft: target.x + target.shift.x
    readonly property real islandTop: target.y + target.shift.y

    x: Math.min(islandLeft, leading.x) - padding
    y: Math.min(islandTop, leading.y, trailing.y) - padding
    width: Math.max(islandLeft + target.width, trailing.x + trailing.width) + padding - x
    height: Math.max(islandTop + target.height, leading.y + leading.height, trailing.y + trailing.height)
        + padding - y
    visible: shaderFile !== ""

    function circle(item) {
        return Qt.vector4d(item.x + item.width / 2 - x, item.y + item.height / 2 - y, item.diameter, item.blend)
    }

    property vector2d resolution: Qt.vector2d(width, height)
    property color fillColor: Theme.Colors.background
    property color ringColor: Theme.Colors.ring
    property color shadowColor: Theme.Colors.shadow
    property vector4d island: Qt.vector4d(islandLeft - x, islandTop - y, target.width, target.height)
    property real islandRadius: target.radius
    property vector4d leftCircle: circle(leading)
    property vector4d rightCircle: circle(trailing)

    fragmentShader: shaderFile ? "file://" + shaderFile.split("/").map(encodeURIComponent).join("/") : ""

    // Home Manager publishes the compiled shader's store path here.
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
