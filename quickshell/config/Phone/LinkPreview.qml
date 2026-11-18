import QtQuick
import Quickshell.Widgets
import "../Theme" as Theme

ClippingRectangle {
    id: preview

    required property string url
    required property var page
    required property real pt
    required property color accent
    required property color ink
    required property color secondaryInk
    readonly property real contentWidth: width - 20 * pt
    readonly property bool imageReady: image.status === Image.Ready
    readonly property real imageHeight: imageReady
        ? Math.min(contentWidth * image.implicitHeight / image.implicitWidth, contentWidth * 1.2) : 0

    height: details.height + 16 * pt
    radius: 6 * pt
    color: Qt.rgba(accent.r, accent.g, accent.b, 0.12)

    Rectangle {
        width: 3 * preview.pt
        height: parent.height
        color: preview.accent
    }

    Column {
        id: details
        x: 12 * preview.pt
        y: 8 * preview.pt
        width: preview.contentWidth
        spacing: 2 * preview.pt

        Text {
            width: parent.width
            text: preview.page.site
            color: preview.accent
            elide: Text.ElideRight
            font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 14 * preview.pt }
        }

        Text {
            visible: text !== ""
            width: parent.width
            text: preview.page.title
            color: preview.ink
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 14 * preview.pt }
        }

        Text {
            visible: text !== ""
            width: parent.width
            text: preview.page.description
            color: preview.secondaryInk
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            font { family: Theme.Fonts.family; pixelSize: 13 * preview.pt }
        }

        Item {
            visible: preview.imageReady
            width: parent.width
            height: preview.imageHeight + 4 * preview.pt

            ClippingRectangle {
                y: 4 * preview.pt
                width: parent.width
                height: preview.imageHeight
                radius: 6 * preview.pt
                color: "transparent"

                Image {
                    id: image
                    anchors.fill: parent
                    source: preview.page.image
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: preview.contentWidth * 2
                    asynchronous: true
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Qt.openUrlExternally(preview.url)
    }
}
