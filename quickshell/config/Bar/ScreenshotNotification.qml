import QtQuick
import Quickshell.Widgets
import "../Theme" as Theme

Item {
    id: root

    property string filePath: ""
    readonly property url imageUrl: filePath
        ? "file://" + filePath.split("/").map(encodeURIComponent).join("/") : ""

    implicitWidth: 420
    implicitHeight: 72

    Row {
        id: contentRow
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ClippingRectangle {
            id: thumbnail
            width: 64
            height: contentRow.height
            radius: 6
            color: Theme.Colors.activeWorkspace

            Image {
                anchors.fill: parent
                source: root.imageUrl
                sourceSize.width: 128
                sourceSize.height: 96
                asynchronous: true
                fillMode: Image.PreserveAspectFit
            }
        }

        Text {
            width: contentRow.width - thumbnail.width - contentRow.spacing
            height: contentRow.height
            text: root.filePath
            textFormat: Text.PlainText
            color: Theme.Colors.foreground
            font.pixelSize: 12
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
