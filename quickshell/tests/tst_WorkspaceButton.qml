import QtQuick
import QtTest
import Quickshell.Hyprland
import "Bar" as Bar
import "Theme" as Theme

TestCase {
    name: "WorkspaceButton"
    when: windowShown
    visible: true
    width: 100
    height: 100

    Component {
        id: buttonComponent
        Bar.WorkspaceButton {}
    }

    function init() {
        Hyprland.focusedWorkspace = { id: 1 }
        Hyprland.requests = []
    }

    function test_click_focuses_workspace_data() {
        return [
            { tag: "workspace-two", workspace: 2 },
            { tag: "workspace-ten", workspace: 10 }
        ]
    }

    function test_click_focuses_workspace(data) {
        const button = createTemporaryObject(buttonComponent, this, { workspaceId: data.workspace })
        mouseClick(button, button.width / 2, button.height / 2)
        compare(Hyprland.requests.length, 1)
        compare(Hyprland.focusedWorkspace.id, data.workspace)
        compare(button.color, Theme.Colors.activeWorkspace)
    }
}
