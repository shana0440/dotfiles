import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Rectangle {
    id: root

    property bool merged: false
    signal clicked()

    width: 32
    height: 32
    radius: height / 2
    color: Theme.Colors.background
    opacity: merged ? 0 : 1
    visible: (Services.Media.playing || merged) && opacity > 0
    enabled: !merged

    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    Components.PlayingIndicator {
        anchors.fill: parent
        radius: height / 2
        playing: Services.Media.playing
        levels: Services.Cava.groupedBars(5)
        tooltip: "Now playing: " + Services.Media.title
        onClicked: root.clicked()
    }
}
