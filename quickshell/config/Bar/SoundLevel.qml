import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    property var node: null
    property string icon: ""
    property string mutedIcon: ""
    property string iconSource: ""
    property string label: ""
    property string what: ""
    property bool openable: false
    readonly property var audio: node?.audio ?? null
    readonly property bool muted: audio?.muted ?? false
    readonly property real volume: audio?.volume ?? 0
    signal opened()

    width: parent ? parent.width : 0
    height: 50

    Components.IconButton {
        id: mute
        x: -6
        anchors.verticalCenter: slider.verticalCenter
        width: 32
        height: 32
        iconSize: root.iconSource ? 0 : 16
        enabled: root.audio !== null
        icon: root.muted ? root.mutedIcon : root.icon
        iconColor: root.muted ? Theme.Colors.muted : Theme.Colors.foreground
        tooltip: root.muted ? "Unmute " + root.what : "Mute " + root.what
        onClicked: Services.Sound.toggleMute(root.node)

        Image {
            anchors.centerIn: parent
            width: 18
            height: 18
            visible: root.iconSource !== ""
            source: root.iconSource
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            opacity: root.muted ? 0.35 : 1
        }
    }

    Text {
        anchors.left: slider.left
        anchors.right: percent.right
        y: 30
        text: root.label
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Theme.Colors.muted
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        font.pixelSize: 11
    }

    Item {
        id: slider
        anchors.left: mute.right
        anchors.leftMargin: 6
        anchors.right: percent.left
        anchors.rightMargin: 10
        y: 4
        height: 24
        enabled: root.audio !== null

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Theme.Colors.track

            Rectangle {
                width: track.width * Math.max(0, Math.min(1, root.volume))
                height: parent.height
                radius: parent.radius
                color: Theme.Colors.foreground
                opacity: root.muted ? 0.35 : 1
            }
        }
        Rectangle {
            x: track.width * Math.max(0, Math.min(1, root.volume)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: drag.pressed ? 16 : 14
            height: width
            radius: width / 2
            color: Theme.Colors.foreground
            visible: slider.enabled && !root.muted
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => Services.Sound.setVolume(root.node, mouse.x / width)
            onPositionChanged: mouse => {
                if (pressed)
                    Services.Sound.setVolume(root.node, mouse.x / width)
            }
            onWheel: wheel => Services.Sound.setVolume(root.node,
                root.volume + (wheel.angleDelta.y || wheel.angleDelta.x) / 120 * 0.05)
        }
    }

    Text {
        id: percent
        anchors.right: open.visible ? open.left : parent.right
        anchors.rightMargin: open.visible ? 2 : 0
        anchors.verticalCenter: slider.verticalCenter
        width: 40
        horizontalAlignment: Text.AlignRight
        text: root.audio ? (root.muted ? "Muted" : Math.round(root.volume * 100) + "%") : "—"
        color: root.muted ? Theme.Colors.muted : Theme.Colors.foreground
        font.family: root.muted ? Theme.Fonts.family : Theme.Fonts.mono
        font.weight: root.muted ? Theme.Fonts.weight : Font.Normal
        font.pixelSize: root.muted ? 12 : 13
    }

    Components.IconButton {
        id: open
        visible: root.openable
        anchors.right: parent.right
        anchors.rightMargin: -6
        anchors.verticalCenter: slider.verticalCenter
        width: 32
        height: 32
        iconSize: 16
        icon: "forward"
        iconColor: Theme.Colors.muted
        tooltip: "Choose " + root.what + " device"
        onClicked: root.opened()
    }
}
