import QtQuick
import Quickshell.Widgets

ClippingRectangle {
    property real pt: 1
    default property alias rows: rowColumn.data
    x: 16 * pt
    width: parent.width - 2 * x
    height: rowColumn.height
    radius: 22 * pt
    color: Look.groupFill

    Column {
        id: rowColumn
        width: parent.width
    }
}
