import QtQuick
import QtQuick.Effects

// A Lucide icon tinted to one color. Icon.qml rewrites the SVG text, which needs
// Quickshell; this only uses Qt Quick, so the SDDM greeter can load it too.
Item {
    id: root

    property string name: "power"
    property color color: "white"

    implicitWidth: 18
    implicitHeight: 18

    Image {
        id: svg
        anchors.fill: parent
        source: Qt.resolvedUrl("../Icons/lucide/" + root.name + ".svg")
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        visible: false
    }

    // Lucide strokes are black; lift them to white, then tint.
    MultiEffect {
        anchors.fill: parent
        source: svg
        brightness: 1
        colorization: 1
        colorizationColor: root.color
    }
}
