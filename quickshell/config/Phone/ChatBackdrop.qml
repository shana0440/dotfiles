import QtQuick
import "../Services" as Services

Item {
    property string source: Services.ChatBackground.image
    property bool dimmed: Services.ChatBackground.usingCustom

    Image {
        anchors.fill: parent
        source: parent.source
        fillMode: Image.PreserveAspectCrop
        sourceSize { width: width * 2; height: height * 2 }
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        visible: parent.dimmed
        color: "black"
        opacity: 0.3
    }
}
