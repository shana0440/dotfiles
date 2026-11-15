import QtQuick
import "../Components" as Components

Components.Surface {
    width: workspaceRow.width + 6
    radius: height / 2

    Row {
        id: workspaceRow
        anchors.centerIn: parent

        Repeater {
            model: 10

            WorkspaceButton {
                required property int index
                workspaceId: index + 1
            }
        }
    }
}
