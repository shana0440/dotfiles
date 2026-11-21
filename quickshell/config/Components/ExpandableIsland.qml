import QtQuick
import "../Theme" as Theme

Island {
    id: root

    property bool expanded: false
    property bool held: expanded
    property bool satellitesMerged: held
    property real restingHeight: 32
    readonly property bool raised: expanded || height > restingHeight + 1

    clearness: Theme.Colors.transparentTheme && !held ? 1 : 0
    Behavior on clearness {
        NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
    }
}
