import QtQuick
import "../Theme" as Theme

Rectangle {
    id: root

    property bool merged: false
    property bool available: true
    property bool animateMerge: true

    width: 32
    height: 32
    radius: height / 2
    color: Theme.Colors.background
    opacity: available && !merged ? 1 : 0
    visible: opacity > 0
    enabled: available && !merged

    Behavior on opacity {
        enabled: root.animateMerge
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on anchors.rightMargin {
        enabled: root.animateMerge
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }
    Behavior on anchors.leftMargin {
        enabled: root.animateMerge
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }
}
