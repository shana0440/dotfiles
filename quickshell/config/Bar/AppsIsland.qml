import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Components.Surface {
    id: root

    property real availableWidth: 0
    readonly property int buttonSize: 28
    readonly property int buttonSpacing: 4
    readonly property int padding: 8
    // heuristicLookup() is not reactive; bump this when desktop entries (re)load.
    property int entriesRevision: 0

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.entriesRevision++ }
    }

    visible: windows.count > 0 && availableWidth >= buttonSize + padding * 2
    width: visible ? Math.min(appRow.width + padding * 2, availableWidth) : 0
    radius: 8

    Flickable {
        id: appList
        anchors.fill: parent
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        contentWidth: appRow.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        function revealActive(button) {
            if (!button.modelData.activated)
                return
            contentX = Math.max(0, Math.min(button.x,
                Math.max(contentX, button.x + button.width - width)))
        }

        onContentWidthChanged: contentX = Math.max(0, Math.min(contentX, contentWidth - width))
        onWidthChanged: contentX = Math.max(0, Math.min(contentX, contentWidth - width))

        Row {
            id: appRow
            height: parent.height
            spacing: root.buttonSpacing

            Repeater {
                id: windows
                model: ToplevelManager.toplevels

                Rectangle {
                    id: button
                    required property var modelData
                    readonly property var entry: {
                        root.entriesRevision
                        return DesktopEntries.heuristicLookup(modelData.appId)
                    }
                    readonly property string label: modelData.title || entry?.name || modelData.appId || "Application"

                    Component.onCompleted: Qt.callLater(() => appList.revealActive(button))
                    Connections {
                        target: button.modelData
                        function onActivatedChanged() { appList.revealActive(button) }
                    }

                    width: root.buttonSize
                    height: appList.height
                    radius: 4
                    color: modelData.activated || mouse.containsMouse
                        ? Theme.Colors.highlight : Theme.Colors.transparent

                    Image {
                        id: appIcon
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: Quickshell.iconPath(button.entry?.icon || "application-x-executable", true)
                        sourceSize.width: width
                        sourceSize.height: height
                    }

                    Text {
                        font.family: Theme.Fonts.family
                        font.weight: Theme.Fonts.weight
                        anchors.centerIn: parent
                        visible: appIcon.status !== Image.Ready
                        text: (button.entry?.name || button.modelData.appId || "?").charAt(0).toUpperCase()
                        color: Theme.Colors.foreground
                        font.pixelSize: 14
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 10
                        height: 2
                        radius: 1
                        color: Theme.Colors.foreground
                        visible: button.modelData.activated
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 1
                        width: 7
                        height: 7
                        radius: width / 2
                        color: Theme.Colors.info
                        border.color: Theme.Colors.background
                        border.width: 1
                        visible: Services.LauncherBadges.hasUnread(
                            button.modelData.appId, button.entry?.id || "")
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: button.modelData.activate()
                    }

                    Components.Tooltip {
                        shown: mouse.containsMouse
                        delay: 500
                        alignment: Qt.AlignHCenter
                        text: button.label
                    }
                }
            }
        }
    }

    // Keep the wheel target outside the scrolling content so it never scrolls away.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            const delta = event.angleDelta.y || event.angleDelta.x
            appList.contentX = Math.max(0, Math.min(appList.contentWidth - appList.width,
                appList.contentX - delta / 120 * (root.buttonSize + root.buttonSpacing)))
            event.accepted = true
        }
    }
}
