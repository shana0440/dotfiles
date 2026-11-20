import QtQuick

Item {
    id: root

    default property alias buttons: row.data
    property int step: 32
    readonly property real contentWidth: row.width

    function reveal(button) {
        list.contentX = Math.max(0, Math.min(button.x,
            Math.max(list.contentX, button.x + button.width - list.width)))
    }

    Flickable {
        id: list
        anchors.fill: parent
        contentWidth: row.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        function clamp() { contentX = Math.max(0, Math.min(contentX, contentWidth - width)) }
        onContentWidthChanged: clamp()
        onWidthChanged: clamp()

        Row {
            id: row
            height: parent.height
            spacing: 4
        }
    }

    Item {
        anchors.fill: parent

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = event.angleDelta.y || event.angleDelta.x
                list.contentX = Math.max(0, Math.min(list.contentWidth - list.width,
                    list.contentX - delta / 120 * root.step))
                event.accepted = true
            }
        }
    }
}
