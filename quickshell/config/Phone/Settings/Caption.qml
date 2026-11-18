import QtQuick
import "../../Theme" as Theme

Text {
    property real pt: 1
    property bool note: false
    x: 32 * pt
    width: parent.width - 2 * x
    bottomPadding: note ? 20 * pt : 0
    wrapMode: Text.Wrap
    color: Look.secondaryInk
    font { family: Theme.Fonts.family; pixelSize: 13 * pt }
}
