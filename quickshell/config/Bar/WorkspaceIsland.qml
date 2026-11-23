import QtQuick
import "../Components" as Components

Components.Surface {
    id: root

    signal missionControlRequested()

    width: workspaceRow.width + 6
    radius: height / 2

    Row {
        id: workspaceRow
        anchors.centerIn: parent

        Components.IconButton {
            width: 32
            height: 24
            radius: height / 2
            icon: "nixos"
            iconSize: 16
            tooltip: "Mission Control"
            onClicked: root.missionControlRequested()
        }

        Repeater {
            model: 10

            WorkspaceButton {
                required property int index
                workspaceId: index + 1
            }
        }
    }
}
