import QtQuick
import Quickshell.Widgets
import "../Theme" as Theme

Item {
    id: avatar

    property string name: ""
    property string source: ""
    readonly property bool hasPhoto: photo.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        visible: !avatar.hasPhoto
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: "#ff9ac1" }
            GradientStop { position: 1; color: "#e2588e" }
        }
        Text {
            anchors.centerIn: parent
            text: avatar.name.charAt(0).toUpperCase()
            color: "white"
            font { family: Theme.Fonts.family; weight: Font.Bold; pixelSize: avatar.height * 0.45 }
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        visible: avatar.hasPhoto
        radius: width / 2
        color: "transparent"
        Image {
            id: photo
            anchors.fill: parent
            source: avatar.source
            fillMode: Image.PreserveAspectCrop
            sourceSize { width: avatar.width * 2; height: avatar.height * 2 }
            asynchronous: true
        }
    }
}
