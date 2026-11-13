import QtQuick
import "../Components" as Components

Components.Surface {
    width: workspaceRow.width + 16
    radius: 8

    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: 10

            WorkspaceButton {
                required property int index
                workspaceId: index + 1
            }
        }
    }
}
