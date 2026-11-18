import QtQuick
import Quickshell.Widgets
import "../Theme" as Theme

ClippingRectangle {
    id: photo

    required property string source
    required property real maxWidth
    required property real pt
    readonly property real maxHeight: maxWidth * 1.3
    readonly property bool ready: image.status === Image.Ready
    readonly property real fit: ready
        ? Math.min(maxWidth / image.implicitWidth, maxHeight / image.implicitHeight, 1) : 1

    width: ready ? Math.max(image.implicitWidth * fit, 64 * pt) : maxWidth
    height: ready ? image.implicitHeight * fit : image.status === Image.Error ? 56 * pt : maxWidth * 0.6
    radius: 14 * pt
    color: "#0f1a24"

    Image {
        id: image
        anchors.fill: parent
        source: photo.source
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: photo.maxWidth * 2
        asynchronous: true
    }

    Text {
        anchors.centerIn: parent
        visible: image.status === Image.Error
        width: parent.width - 24 * photo.pt
        text: "Couldn't load " + decodeURIComponent(photo.source.split("/").pop())
        color: "#6c7e8e"
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        font { family: Theme.Fonts.family; pixelSize: 13 * photo.pt }
    }

    MouseArea {
        anchors.fill: parent
        enabled: photo.ready
        cursorShape: Qt.PointingHandCursor
        onClicked: Qt.openUrlExternally(photo.source)
    }
}
