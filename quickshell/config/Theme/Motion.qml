pragma Singleton
import QtQuick

QtObject {
    readonly property real enterStiffness: 320
    readonly property real enterDamping: 26
    readonly property real morphStiffness: 340
    readonly property real morphDamping: 27
    readonly property real closeStiffness: 380
    readonly property real closeDamping: 36
    readonly property real stackStiffness: 400
    readonly property real stackDamping: 36
    readonly property real liquidStiffness: 190
    readonly property real liquidDamping: 19
    readonly property real absorbStiffness: 230
    readonly property real absorbDamping: 27

    readonly property real anticipation: -260
    readonly property real swell: 320
}
