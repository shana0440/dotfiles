import QtQuick
import "../Components" as Components

// A pill of numbered dots for the workspaces in use; the focused one stretches
// into a white bar.
Components.Surface {
    // Ends as far from the dots as the top and bottom.
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
