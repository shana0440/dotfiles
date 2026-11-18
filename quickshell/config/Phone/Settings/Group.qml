import QtQuick

Rectangle {
    property real pt: 1
    default property alias rows: rowColumn.data
    x: 16 * pt
    width: parent.width - 2 * x
    height: rowColumn.height
    radius: 10 * pt
    color: "white"

    Column {
        id: rowColumn
        width: parent.width
    }
}
