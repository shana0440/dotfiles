import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme" as Theme

// One workspace in the Mission Control strip: the wallpaper with a still capture
// of each window where it sits, and its name below.
Item {
    id: root

    required property var workspace
    required property int workspaceId
    required property real thumbHeight
    required property var screenInfo
    property url wallpaper
    // Captures are taken while Mission Control is open, fresh on every open.
    property bool live: false
    property int generation: 0
    property bool current: false
    property bool dropping: false
    signal clicked()

    readonly property real ratio: thumbHeight / Math.max(1, screenInfo.height)

    Rectangle {
        id: frame
        width: parent.width
        height: root.thumbHeight
        radius: 8
        color: Theme.Colors.background
        clip: true

        Image {
            anchors.fill: parent
            source: root.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 480
        }

        Loader {
            anchors.fill: parent
            active: root.live

            sourceComponent: Item {
                Repeater {
                    model: root.workspace.toplevels

                    Item {
                        id: shot
                        required property var modelData
                        readonly property var ipc: modelData.lastIpcObject
                        visible: !!ipc?.at
                        x: ((ipc?.at?.[0] ?? 0) - root.screenInfo.x) * root.ratio
                        y: ((ipc?.at?.[1] ?? 0) - root.screenInfo.y) * root.ratio
                        width: (ipc?.size?.[0] ?? 0) * root.ratio
                        height: (ipc?.size?.[1] ?? 0) * root.ratio
                        // Most recently focused on top.
                        z: 1000 - (ipc?.focusHistoryID ?? 0)

                        Rectangle {
                            anchors.fill: parent
                            visible: !capture.hasContent
                            color: Theme.Colors.surface
                            border.color: Theme.Colors.ring
                        }
                        ScreencopyView {
                            id: capture
                            anchors.fill: parent
                            captureSource: shot.modelData.wayland
                            live: true
                            paintCursor: false
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: frame.radius
            color: "transparent"
            border.width: root.current || root.dropping || mouse.containsMouse ? 2 : 1
            border.color: root.current || root.dropping ? Theme.Colors.foreground
                : mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.5) : Theme.Colors.ring
        }
        Rectangle {
            anchors.fill: parent
            radius: frame.radius
            color: Theme.Colors.foreground
            opacity: root.dropping ? 0.15 : 0
        }
    }

    Text {
        anchors { top: frame.bottom; topMargin: 7; horizontalCenter: parent.horizontalCenter }
        text: "Workspace " + root.workspaceId
        color: root.current ? Theme.Colors.foreground : Theme.Colors.muted
        font.family: Theme.Fonts.family
        font.weight: Theme.Fonts.weight
        font.pixelSize: 12
    }

    MouseArea {
        id: mouse
        anchors.fill: frame
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
