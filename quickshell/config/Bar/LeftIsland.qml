import QtQuick
import "../Theme" as Theme

Rectangle {
    width: workspaceRow.width + 16
    radius: 8
    color: Theme.Colors.background

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
