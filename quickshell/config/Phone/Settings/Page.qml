import QtQuick

Item {
    id: page

    property bool active: false
    property real hiddenBottom: 0
    property string title
    property string backLabel
    property string action
    property bool actionEnabled: true
    property bool holdBack: false
    property real topPadding: 24 * pt
    default property alias content: sections.data
    property alias overlays: overlayLayer.data
    readonly property real pt: width / 390
    signal back
    signal backHeld
    signal actionTriggered

    function focusPage() { body.forceActiveFocus() }
    function reveal(item, rect) {
        const top = item.mapToItem(body.contentItem, rect.x, rect.y).y
        if (top < body.contentY) body.contentY = top
        else if (top + rect.height > body.contentY + body.height) body.contentY = top + rect.height - body.height
    }
    function requestBack() {
        if (holdBack) backHeld()
        else back()
    }

    Rectangle {
        anchors.fill: parent
        color: Look.pageFill
    }

    Flickable {
        id: body
        anchors { top: navBar.bottom; bottom: parent.bottom; bottomMargin: page.hiddenBottom; left: parent.left; right: parent.right }
        contentHeight: sections.height + 32 * page.pt
        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        clip: true
        Keys.onEscapePressed: page.requestBack()

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const step = event.pixelDelta.y || event.angleDelta.y / 120 * 60 * page.pt
                body.contentY = Math.max(0, Math.min(body.contentHeight - body.height, body.contentY - step))
            }
        }

        MouseArea {
            width: body.width
            height: Math.max(body.height, body.contentHeight)
            onClicked: body.forceActiveFocus()
        }

        Column {
            id: sections
            y: page.topPadding
            width: body.width
            spacing: 8 * page.pt
        }
    }

    NavBar {
        id: navBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        pt: page.pt
        active: page.active
        title: page.title
        backLabel: page.backLabel
        action: page.action
        actionEnabled: page.actionEnabled
        onBack: page.requestBack()
        onActionTriggered: page.actionTriggered()
    }

    Item {
        id: overlayLayer
        anchors.fill: parent
    }
}
