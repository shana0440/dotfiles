import QtQuick

Item {
    id: page

    property bool active: false
    property real hiddenBottom: 0
    property string title
    property string backLabel
    default property alias content: sections.data
    property alias overlays: overlayLayer.data
    readonly property real pt: width / 390
    signal back

    function focusPage() { body.forceActiveFocus() }

    Rectangle {
        anchors.fill: parent
        color: Look.pageFill
    }

    Flickable {
        id: body
        anchors { top: navBar.bottom; bottom: parent.bottom; bottomMargin: page.hiddenBottom; left: parent.left; right: parent.right }
        contentHeight: sections.height + 32 * page.pt
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Keys.onEscapePressed: page.back()

        MouseArea {
            width: body.width
            height: Math.max(body.height, body.contentHeight)
            onClicked: body.forceActiveFocus()
        }

        Column {
            id: sections
            y: 24 * page.pt
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
        onBack: page.back()
    }

    Item {
        id: overlayLayer
        anchors.fill: parent
    }
}
