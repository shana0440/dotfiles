import QtQuick
import QtQuick.Shapes
import Quickshell
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: chat

    property real hiddenBottom: 0
    property bool active: false
    readonly property real pt: width / 390
    readonly property color ink: "#ffffff"
    readonly property color secondaryInk: "#8e8e93"
    readonly property color accent: "#0a84ff"
    readonly property color link: "#64b5ff"
    readonly property color barFill: "#161618"
    readonly property color hairline: "#38383a"
    readonly property color incomingFill: "#262628"
    readonly property color outgoingFill: "#2b5a3c"
    readonly property color outgoingInk: "#8fd3a0"
    readonly property color fieldFill: "#1c1c1e"
    readonly property color fieldBorder: "#38383a"
    readonly property color placeholder: "#6e6e73"
    readonly property color pillFill: Qt.rgba(0, 0, 0, 0.4)
    signal dismissed
    signal settingsRequested

    function focusPage() { composer.forceActiveFocus() }
    function submit() {
        Services.Mei.send(composer.text)
        composer.clear()
        history.followBottom = true
    }

    Rectangle {
        anchors.fill: parent
        color: "#0d0d10"
    }

    ChatBackdrop {
        anchors.fill: parent
    }

    ListView {
        id: history
        property bool followBottom: true
        property real swipeVelocity: 0
        property real lastSwipeTime: 0
        readonly property real topY: originY - topMargin
        readonly property real bottomY: Math.max(topY, originY + contentHeight + bottomMargin - height)

        function clampY(y) { return Math.max(topY, Math.min(bottomY, y)) }

        function scrollTo(y) {
            contentY = y
            followBottom = y >= bottomY - 1
        }

        function glideBy(distance) {
            const to = clampY((glide.running ? glide.to : contentY) + distance)
            glide.from = contentY
            glide.to = to
            followBottom = to >= bottomY - 1
            glide.restart()
        }

        function swipe(event) {
            const now = Date.now()
            const elapsed = Math.max(1, now - lastSwipeTime) / 1000
            const velocity = event.pixelDelta.y / elapsed
            swipeVelocity = elapsed > 0.1 ? velocity : swipeVelocity * 0.6 + velocity * 0.4
            lastSwipeTime = now
            scrollTo(clampY(contentY - event.pixelDelta.y))
        }

        function wheel(event) {
            if (event.phase === Qt.ScrollEnd) {
                if (Date.now() - lastSwipeTime < 80) flick(0, swipeVelocity)
                swipeVelocity = 0
                return
            }
            cancelFlick()
            if (event.pixelDelta.y !== 0) {
                glide.stop()
                swipe(event)
            } else {
                glideBy(-event.angleDelta.y / 120 * 100 * chat.pt)
            }
        }
        anchors { bottom: inputBar.top; left: parent.left; right: parent.right }
        height: Math.min(inputBar.y - header.height, contentHeight + topMargin + bottomMargin)
        topMargin: 8 * chat.pt
        bottomMargin: 8 * chat.pt
        spacing: 3 * chat.pt
        clip: true
        model: Services.Mei.messages
        boundsBehavior: Flickable.StopAtBounds
        onMovementEnded: followBottom = atYEnd

        NumberAnimation {
            id: glide
            target: history
            property: "contentY"
            duration: 220
            easing.type: Easing.OutCubic
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => history.wheel(event)
        }
        onCountChanged: Qt.callLater(positionViewAtEnd)
        onContentHeightChanged: if (followBottom) Qt.callLater(positionViewAtEnd)
        onHeightChanged: if (followBottom) Qt.callLater(positionViewAtEnd)

        delegate: Loader {
            id: row
            required property int index
            required property string kind
            required property string text
            required property string time
            required property bool streaming
            readonly property bool lastOfGroup: index === history.count - 1
                || Services.Mei.messages.get(index + 1)?.kind !== kind
            width: ListView.view.width
            sourceComponent: kind === "user" || kind === "mei" ? bubble : servicePill

            Component {
                id: servicePill
                Item {
                    implicitHeight: pill.height + 12 * chat.pt
                    Rectangle {
                        id: pill
                        anchors.centerIn: parent
                        width: pillText.width + 16 * chat.pt
                        height: pillText.height + 6 * chat.pt
                        radius: Math.min(height / 2, 12 * chat.pt)
                        color: chat.pillFill
                        Text {
                            id: pillText
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, row.width - 64 * chat.pt)
                            text: row.text
                            color: "white"
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 13 * chat.pt }
                        }
                    }
                }
            }

            Component {
                id: bubble
                Item {
                    id: bubbleRow
                    readonly property bool outgoing: row.kind === "user"
                    readonly property real maxTextWidth: row.width * 0.74 - 24 * chat.pt
                    readonly property real stampWidth: stamp.implicitWidth + 8 * chat.pt
                    readonly property bool stampInline: body.lineCount <= 1
                        && body.implicitWidth + stampWidth <= maxTextWidth
                    readonly property bool typing: row.streaming && row.text === ""
                    implicitHeight: card.height + (row.lastOfGroup ? 6 * chat.pt : 0)

                    Rectangle {
                        id: card
                        readonly property real sharp: row.lastOfGroup ? 4 * chat.pt : 16 * chat.pt
                        x: bubbleRow.outgoing ? parent.width - width - 10 * chat.pt : 10 * chat.pt
                        width: bubbleRow.typing ? 58 * chat.pt
                            : Math.max(body.width + (bubbleRow.stampInline ? bubbleRow.stampWidth : 0),
                                       bubbleRow.stampWidth) + 24 * chat.pt
                        height: bubbleRow.typing ? 36 * chat.pt
                            : body.height + (bubbleRow.stampInline ? 0 : stamp.height) + 14 * chat.pt
                        radius: 17 * chat.pt
                        bottomLeftRadius: bubbleRow.outgoing ? radius : sharp
                        bottomRightRadius: bubbleRow.outgoing ? sharp : radius
                        color: bubbleRow.outgoing ? chat.outgoingFill : chat.incomingFill

                        Shape {
                            visible: row.lastOfGroup
                            width: 10 * chat.pt
                            height: 14 * chat.pt
                            anchors.bottom: parent.bottom
                            x: bubbleRow.outgoing ? parent.width - 2 * chat.pt : -width + 2 * chat.pt
                            transform: Scale { origin.x: 5 * chat.pt; xScale: bubbleRow.outgoing ? -1 : 1 }
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeWidth: -1
                                fillColor: card.color
                                PathSvg {
                                    path: "M " + 10 * chat.pt + " 0 C " + 10 * chat.pt + " " + 7 * chat.pt + " "
                                        + 8 * chat.pt + " " + 12 * chat.pt + " 0 " + 14 * chat.pt + " L "
                                        + 10 * chat.pt + " " + 14 * chat.pt + " Z"
                                }
                            }
                        }

                        Row {
                            visible: bubbleRow.typing
                            anchors.centerIn: parent
                            spacing: 5 * chat.pt
                            Repeater {
                                model: 3
                                Rectangle {
                                    required property int index
                                    width: 7 * chat.pt
                                    height: width
                                    radius: width / 2
                                    color: chat.secondaryInk
                                    SequentialAnimation on opacity {
                                        running: bubbleRow.typing
                                        loops: Animation.Infinite
                                        PauseAnimation { duration: index * 160 }
                                        NumberAnimation { from: 0.3; to: 1; duration: 320 }
                                        NumberAnimation { from: 1; to: 0.3; duration: 320 }
                                        PauseAnimation { duration: (2 - index) * 160 }
                                    }
                                }
                            }
                        }

                        Text {
                            id: body
                            visible: !bubbleRow.typing
                            x: 12 * chat.pt
                            y: 7 * chat.pt
                            width: Math.min(implicitWidth, bubbleRow.maxTextWidth)
                            text: bubbleRow.outgoing ? row.text : row.text.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g,
                                '<a href="$2"><span style="color: ' + chat.link + '">$1</span></a>')
                            textFormat: bubbleRow.outgoing ? Text.PlainText : Text.MarkdownText
                            wrapMode: Text.Wrap
                            color: chat.ink
                            lineHeight: 1.08
                            font { family: Theme.Fonts.family; weight: Font.Normal; pixelSize: 16 * chat.pt }
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }

                        Row {
                            id: stamp
                            visible: !bubbleRow.typing
                            anchors { right: parent.right; rightMargin: 10 * chat.pt; bottom: parent.bottom; bottomMargin: 5 * chat.pt }
                            spacing: 3 * chat.pt
                            Text {
                                text: row.time
                                color: bubbleRow.outgoing ? chat.outgoingInk : chat.secondaryInk
                                font { family: Theme.Fonts.family; pixelSize: 11 * chat.pt }
                            }
                            Components.Icon {
                                visible: bubbleRow.outgoing
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14 * chat.pt
                                height: width
                                action: "checkDouble"
                                iconColor: chat.outgoingInk
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        x: (parent.width - width) / 2
        y: (header.height + inputBar.y - height) / 2
        visible: history.count === 0
        width: emptyText.width + 32 * chat.pt
        height: emptyText.height + 24 * chat.pt
        radius: 16 * chat.pt
        color: chat.pillFill
        Text {
            id: emptyText
            anchors.centerIn: parent
            text: "No messages here yet\nSay hi to " + Services.Mei.name
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.2
            color: "white"
            font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 14 * chat.pt }
        }
    }

    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 104 * chat.pt
        color: Qt.alpha(chat.barFill, 0.96)

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: chat.hairline
        }

        StatusBar {
            id: statusBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 54 * chat.pt
            pt: chat.pt
            active: chat.active
            ink: chat.ink
        }

        Column {
            anchors { horizontalCenter: parent.horizontalCenter; top: statusBar.bottom; topMargin: 3 * chat.pt }
            spacing: 1 * chat.pt
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Services.Mei.name
                color: chat.ink
                font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 17 * chat.pt }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Services.Mei.presence
                color: Services.Mei.presence === "online" || Services.Mei.presence === "offline"
                    ? chat.secondaryInk : chat.accent
                font { family: Theme.Fonts.family; pixelSize: 13 * chat.pt }
            }
        }

        Avatar {
            anchors { right: parent.right; rightMargin: 12 * chat.pt; top: statusBar.bottom; topMargin: 4 * chat.pt }
            width: 38 * chat.pt
            height: width
            name: Services.Mei.name
            source: Services.Mei.avatar
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: chat.settingsRequested()
            }
        }
    }

    Rectangle {
        id: inputBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: chat.hiddenBottom }
        height: field.height + 16 * chat.pt
        color: chat.barFill

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: chat.hairline
        }

        Rectangle {
            id: field
            anchors { left: parent.left; leftMargin: 12 * chat.pt; right: sendButton.left; rightMargin: 8 * chat.pt; verticalCenter: parent.verticalCenter }
            height: Math.min(composer.contentHeight, 5 * 21 * chat.pt) + 14 * chat.pt
            radius: 18 * chat.pt
            color: chat.fieldFill
            border { width: 1; color: chat.fieldBorder }

            Flickable {
                id: composerScroll
                anchors { fill: parent; leftMargin: 14 * chat.pt; rightMargin: 12 * chat.pt; topMargin: 7 * chat.pt; bottomMargin: 7 * chat.pt }
                contentHeight: composer.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: composer
                    width: composerScroll.width
                    wrapMode: TextEdit.Wrap
                    color: chat.ink
                    selectionColor: Qt.alpha(chat.accent, 0.3)
                    selectedTextColor: chat.ink
                    font { family: Theme.Fonts.family; pixelSize: 16 * chat.pt }
                    onCursorRectangleChanged: composerScroll.contentY = Math.max(0,
                        Math.min(cursorRectangle.y, contentHeight - composerScroll.height))
                    Keys.onEscapePressed: chat.dismissed()
                    Keys.onReturnPressed: event => {
                        if (event.modifiers & Qt.ShiftModifier) event.accepted = false
                        else chat.submit()
                    }
                    Keys.onEnterPressed: chat.submit()

                    Text {
                        visible: !composer.text && !composer.preeditText
                        text: "Message"
                        color: chat.placeholder
                        font: composer.font
                    }
                }
            }
        }

        Rectangle {
            id: sendButton
            readonly property bool ready: composer.text.trim() !== ""
            anchors { right: parent.right; rightMargin: 10 * chat.pt; bottom: field.bottom; bottomMargin: 1 * chat.pt }
            width: 32 * chat.pt
            height: width
            radius: width / 2
            color: ready ? chat.accent : chat.fieldBorder
            Behavior on color { ColorAnimation { duration: 120 } }

            Components.Icon {
                anchors.centerIn: parent
                width: 18 * chat.pt
                height: width
                action: "send"
                iconColor: "white"
            }
            MouseArea {
                anchors.fill: parent
                enabled: sendButton.ready
                cursorShape: Qt.PointingHandCursor
                onClicked: chat.submit()
            }
        }
    }
}
