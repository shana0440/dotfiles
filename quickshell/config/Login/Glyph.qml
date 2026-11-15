import QtQuick
import QtQuick.Effects

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

    MultiEffect {
        anchors.fill: parent
        source: svg
        brightness: 1
        colorization: 1
        colorizationColor: root.color
    }
}
