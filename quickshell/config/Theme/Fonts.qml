pragma Singleton
import QtQuick

// One typeface for the whole shell. Text sets weight only when it needs more than the
// default; explicit bold stays bold.
QtObject {
    readonly property string family: "Inter"
    readonly property int weight: Font.DemiBold
}
