import QtQuick
import Quickshell
import "Bar" as BarComponents
import "Theme" as Theme

PanelWindow {
    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 20
        left: 20
        right: 20
    }

    implicitHeight: 32
    color: Theme.Colors.transparent

    BarComponents.Workspaces {
        anchors.left: parent.left
        height: parent.height
    }

    BarComponents.DateTime {
        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height
    }

    BarComponents.RightSection {
        anchors.right: parent.right
        height: parent.height
    }
}
