import QtQuick
import "../Components" as Components
import "../Services" as Services

Components.MergeableCircle {
    id: root

    signal clicked()
    available: Services.Media.playing

    Components.PlayingIndicator {
        anchors.fill: parent
        radius: height / 2
        playing: Services.Media.playing
        levels: Services.Cava.groupedBars(5)
        tooltip: "Now playing: " + Services.Media.title
        onClicked: root.clicked()
    }
}
