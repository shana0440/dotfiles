import QtQuick

QtObject {
    property string text
    property int cursor: 0
    property string error
    property bool done: false
    signal finished(string failure)

    function reset(value) {
        text = value
        cursor = 0
        error = ""
    }
    function finish(failure) {
        error = failure
        done = !failure
        finished(failure)
    }
}
