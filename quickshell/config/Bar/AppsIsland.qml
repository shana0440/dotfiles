import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Components.MergeableCircle {
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

    available: windows.count > 0 && availableWidth >= buttonSize + padding * 2
    width: widthSpring.value
    height: islandHeight

    Components.Spring {
        id: widthSpring
        to: root.padding * 2 + windowStrip.width
        stiffness: Theme.Motion.morphStiffness
        damping: Theme.Motion.morphDamping
        Component.onCompleted: snap()
    }

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
