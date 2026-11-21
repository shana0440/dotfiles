import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Components" as Components
import "../Services" as Services

Components.Island {
    id: root

    property real availableWidth: 0
    property int islandHeight: 32
    readonly property int buttonSize: 28
    readonly property int buttonSpacing: 4
    readonly property int padding: 8
    property int entriesRevision: 0

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.entriesRevision++ }
    }

    visible: windows.count > 0 && availableWidth >= buttonSize + padding * 2
    alignment: Qt.AlignRight
    targetRadius: islandHeight / 2
    activeView: windowsView

    views: [
        Item {
            id: windowsView
            width: root.padding * 2 + windowStrip.width
            height: root.islandHeight

            AppStrip {
                id: windowStrip
                x: root.padding
                y: 4
                width: Math.max(0, Math.min(contentWidth, root.availableWidth - root.padding * 2))
                height: parent.height - 8
                step: root.buttonSize + root.buttonSpacing

                Repeater {
                    id: windows
                    model: ToplevelManager.toplevels

                    AppButton {
                        id: windowButton
                        required property var modelData
                        readonly property var entry: {
                            root.entriesRevision
                            return DesktopEntries.heuristicLookup(modelData.appId)
                        }

                        label: modelData.title || entry?.name || modelData.appId || "Application"
                        iconSource: Quickshell.iconPath(entry?.icon || "application-x-executable", true)
                        active: modelData.activated
                        badged: Services.LauncherBadges.hasUnread(modelData.appId, entry?.id || "")
                        onPressed: mouseButton => {
                            if (mouseButton === Qt.LeftButton)
                                modelData.activate()
                        }

                        function revealIfActive() {
                            if (modelData.activated)
                                windowStrip.reveal(windowButton)
                        }
                        Component.onCompleted: Qt.callLater(revealIfActive)
                        Connections {
                            target: windowButton.modelData
                            function onActivatedChanged() { windowButton.revealIfActive() }
                        }
                    }
                }
            }
        }
    ]

    IpcHandler {
        target: "apps"
        function state(): string {
            return JSON.stringify({
                windows: ToplevelManager.toplevels.values.map(window => ({
                    appId: window.appId, title: window.title, active: window.activated
                }))
            })
        }
    }
}
