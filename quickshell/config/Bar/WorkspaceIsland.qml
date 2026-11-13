import QtQuick
import "../Components" as Components

// A pill of numbered dots for the workspaces in use; the focused one stretches
// into a white bar.
Components.Surface {
    width: workspaceRow.width + 12
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
