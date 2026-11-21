import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Components.Island {
    id: root

    property int islandHeight: 32
    readonly property int buttonSize: 28
    readonly property int buttonSpacing: 4
    readonly property int padding: 8

    alignment: Qt.AlignRight
    targetRadius: islandHeight / 2
    activeView: compactView

    views: [
        Item {
            id: compactView
            width: root.padding * 2 + root.buttonSize
            height: root.islandHeight
        }
    ]

    Components.IconButton {
        id: speaker
        z: 1
        anchors.right: parent.right
        anchors.rightMargin: root.padding
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.buttonSize
        implicitHeight: root.islandHeight - 8
        radius: 4
        iconSize: 18
        enabled: Services.Sound.audio !== null
        icon: Services.Sound.muted || Services.Sound.volume === 0 ? "speakerMuted"
            : Services.Sound.volume < 0.34 ? "speakerLow"
            : Services.Sound.volume < 0.67 ? "speakerMedium" : "speaker"
        tooltip: Services.Sound.muted ? "Muted" : "Volume " + Math.round(Services.Sound.volume * 100) + "%"

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => Services.Sound.setVolume(Services.Sound.sink,
                Services.Sound.volume + (event.angleDelta.y || event.angleDelta.x) / 120 * 0.05)
        }
    }
}
