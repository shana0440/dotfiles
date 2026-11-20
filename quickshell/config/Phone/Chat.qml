import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "ChatMarkdown.js" as ChatMarkdown
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
    readonly property color incomingFill: "#182533"
    readonly property color inlineCodeFill: "#35495e"
    readonly property color incomingStamp: "#6c7e8e"
    readonly property color outgoingFill: "#2b5278"
    readonly property color outgoingStamp: "#7da8d3"
    readonly property color readTicks: "#6bbfff"
    readonly property color fieldFill: "#1c1c1e"
    readonly property color fieldBorder: "#38383a"
    readonly property color placeholder: "#6e6e73"
    readonly property color pillFill: Qt.rgba(0, 0, 0, 0.4)
    signal dismissed
    signal settingsRequested

    property var attachment: null
    property TextEdit selectedMessage: null
    property string pasteError: ""
    readonly property bool readyToSend: !clipboard.running && !Services.Mei.resetting
        && (attachment !== null || composer.text.trim() !== "")

    function focusPage() { composer.forceActiveFocus() }
    function selectMessage(message) {
        if (selectedMessage && selectedMessage !== message) selectedMessage.deselect()
        selectedMessage = message
    }
    function submit() {
        if (!readyToSend) return
        Services.Mei.send(composer.text, attachment)
        attachment = null
        pasteError = ""
        composer.clear()
        history.followBottom = true
    }

    function removeAttachment() {
        if (attachment) discardAttachment.createObject(chat, { path: attachment.path })
        attachment = null
        pasteError = ""
    }

    Connections {
        target: Services.Mei
        function onResettingChanged() { if (Services.Mei.resetting) chat.removeAttachment() }
    }

    Process {
        id: clipboard
        command: ["mei-chat-clipboard", Services.Mei.home]
        stdout: StdioCollector { id: clipboardOutput }
        onExited: code => {
            if (code !== 0 || !clipboardOutput.text) {
                chat.pasteError = "Couldn't check the clipboard."
                return
            }
            const result = JSON.parse(clipboardOutput.text)
            if (result.error) chat.pasteError = result.error
            else if (!result.path) {
                if (composer.activeFocus) composer.paste()
            } else if (chat.attachment || Services.Mei.resetting) {
                discardAttachment.createObject(chat, { path: result.path })
                if (chat.attachment) chat.pasteError = "Remove the current attachment before pasting another."
            } else chat.attachment = result
        }
    }

    Component {
        id: discardAttachment
        Process {
            required property string path
            command: ["mei-chat-clipboard", Services.Mei.home, path]
            running: true
            onExited: destroy()
        }
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
        readonly property bool farFromBottom: bottomY - contentY > height / 3

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

        function goToBottom() {
            cancelFlick()
            glideBy(bottomY - contentY)
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
        interactive: false
        onMovementEnded: followBottom = atYEnd

        NumberAnimation {
            id: glide
            target: history
            property: "contentY"
            duration: 220
            easing.type: Easing.OutCubic
            onFinished: if (history.followBottom) history.positionViewAtEnd()
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => history.wheel(event)
        }
        onCountChanged: if (followBottom) Qt.callLater(positionViewAtEnd)
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
                    readonly property bool stampInline: !hasPreview && body.lineCount <= 1
                        && body.implicitWidth + stampWidth <= maxTextWidth
                    readonly property bool typing: row.streaming && row.text === ""
                    readonly property var content: outgoing ? Services.Mei.splitUserAttachment(row.text)
                        : Services.Mei.splitPhotos(row.text)
                    readonly property bool hasPhotos: content.photos.length > 0
                    readonly property bool hasRecording: outgoing && content.recording !== ""
                    readonly property bool hasMedia: hasPhotos || hasRecording
                    readonly property bool hasCaption: content.caption !== ""
                    readonly property bool mediaOnly: hasMedia && !hasCaption
                    readonly property string previewUrl: outgoing || hasPhotos ? ""
                        : Services.LinkPreviews.firstLink(content.caption, row.streaming)
                    readonly property var previewPage: previewUrl ? Services.LinkPreviews.pages[previewUrl] ?? null : null
                    readonly property bool hasPreview: previewPage !== null && !typing
                    readonly property real previewSpace: hasPreview ? linkPreview.height + 6 * chat.pt : 0
                    onPreviewUrlChanged: Services.LinkPreviews.fetch(previewUrl)
                    Component.onCompleted: Services.LinkPreviews.fetch(previewUrl)
                    readonly property real captionTop: hasMedia ? media.height + 3 * chat.pt : 0
                    readonly property real textWidth: Math.max(body.width + (stampInline ? stampWidth : 0),
                                                               stampWidth) + 24 * chat.pt
                    implicitHeight: card.height + (row.lastOfGroup ? 6 * chat.pt : 0)

                    Rectangle {
                        id: card
                        readonly property real sharp: row.lastOfGroup ? 4 * chat.pt : 16 * chat.pt
                        x: bubbleRow.outgoing ? parent.width - width - 10 * chat.pt : 10 * chat.pt
                        width: bubbleRow.typing ? 58 * chat.pt
                            : bubbleRow.mediaOnly ? media.width + 6 * chat.pt
                            : Math.max(bubbleRow.textWidth, bubbleRow.hasMedia ? media.width + 6 * chat.pt : 0,
                                       bubbleRow.hasPreview ? bubbleRow.maxTextWidth + 24 * chat.pt : 0)
                        height: bubbleRow.typing ? 36 * chat.pt
                            : bubbleRow.mediaOnly ? media.height + 6 * chat.pt
                            : bubbleRow.captionTop + body.height + bubbleRow.previewSpace + (bubbleRow.stampInline ? 0 : stamp.height) + 14 * chat.pt
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

                        Column {
                            id: media
                            visible: !bubbleRow.typing && bubbleRow.hasMedia
                            x: 3 * chat.pt
                            y: 3 * chat.pt
                            spacing: 3 * chat.pt
                            Repeater {
                                model: bubbleRow.content.photos
                                ChatPhoto {
                                    required property string modelData
                                    source: modelData
                                    maxWidth: row.width * 0.74 - 6 * chat.pt
                                    pt: chat.pt
                                }
                            }
                            Rectangle {
                                visible: bubbleRow.hasRecording
                                width: 200 * chat.pt
                                height: 58 * chat.pt
                                radius: 14 * chat.pt
                                color: chat.incomingFill
                                Row {
                                    x: 12 * chat.pt
                                    y: 10 * chat.pt
                                    spacing: 8 * chat.pt
                                    Components.Icon {
                                        width: 16 * chat.pt
                                        height: width
                                        anchors.verticalCenter: parent.verticalCenter
                                        action: "play"
                                        iconColor: chat.link
                                    }
                                    Text {
                                        text: "Play recording"
                                        color: chat.ink
                                        font { family: Theme.Fonts.family; pixelSize: 15 * chat.pt }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally(bubbleRow.content.recording)
                                }
                            }
                        }

                        Item {
                            id: body
                            readonly property real markdownLayoutScale: bubbleRow.outgoing ? 1 : 0.5
                            readonly property int lineCount: bodyText.lineCount
                            visible: !bubbleRow.typing && bubbleRow.hasCaption
                            x: 12 * chat.pt
                            y: bubbleRow.captionTop + 7 * chat.pt
                            implicitWidth: bodyText.implicitWidth * markdownLayoutScale
                            implicitHeight: bodyText.height * markdownLayoutScale
                            width: Math.min(implicitWidth, bubbleRow.maxTextWidth)

                            TextEdit {
                                id: bodyText
                                width: body.width / body.markdownLayoutScale
                                readOnly: true
                                selectByMouse: true
                                activeFocusOnPress: false
                                selectionColor: Qt.alpha(chat.accent, 0.45)
                                selectedTextColor: chat.ink
                                onSelectedTextChanged: if (selectedText) chat.selectMessage(bodyText)
                                scale: body.markdownLayoutScale
                                transformOrigin: Item.TopLeft
                                text: bubbleRow.outgoing ? bubbleRow.content.caption : ChatMarkdown.format(
                                    bubbleRow.content.caption, Theme.Fonts.mono, font.pixelSize,
                                    chat.inlineCodeFill, chat.ink, chat.link)
                                textFormat: bubbleRow.outgoing ? TextEdit.PlainText : TextEdit.MarkdownText
                                wrapMode: TextEdit.Wrap
                                color: chat.ink
                                font {
                                    family: Theme.Fonts.family
                                    weight: Font.Normal
                                    pixelSize: 16 * chat.pt / body.markdownLayoutScale
                                }
                                onLinkActivated: link => Qt.openUrlExternally(link)
                            }
                        }

                        LinkPreview {
                            id: linkPreview
                            visible: bubbleRow.hasPreview
                            x: 12 * chat.pt
                            y: body.y + body.height + 6 * chat.pt
                            width: bubbleRow.maxTextWidth
                            url: bubbleRow.previewUrl
                            page: bubbleRow.previewPage ?? { site: "", title: "", description: "", image: "" }
                            pt: chat.pt
                            accent: chat.link
                            ink: chat.ink
                            secondaryInk: chat.secondaryInk
                        }

                        Rectangle {
                            visible: stamp.visible && bubbleRow.mediaOnly
                            anchors { fill: stamp; margins: -3 * chat.pt; leftMargin: -6 * chat.pt; rightMargin: -6 * chat.pt }
                            radius: height / 2
                            color: Qt.rgba(0, 0, 0, 0.5)
                        }

                        Row {
                            id: stamp
                            visible: !bubbleRow.typing
                            anchors {
                                right: parent.right; rightMargin: (bubbleRow.mediaOnly ? 14 : 10) * chat.pt
                                bottom: parent.bottom; bottomMargin: (bubbleRow.mediaOnly ? 12 : 5) * chat.pt
                            }
                            spacing: 3 * chat.pt
                            Text {
                                text: row.time
                                color: bubbleRow.mediaOnly ? "white"
                                    : bubbleRow.outgoing ? chat.outgoingStamp : chat.incomingStamp
                                font { family: Theme.Fonts.family; pixelSize: 11 * chat.pt }
                            }
                            Components.Icon {
                                visible: bubbleRow.outgoing
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14 * chat.pt
                                height: width
                                action: "checkDouble"
                                iconColor: chat.readTicks
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: bottomButton
        readonly property bool shown: history.farFromBottom && !history.followBottom
        anchors { right: parent.right; rightMargin: 12 * chat.pt; bottom: inputBar.top; bottomMargin: 12 * chat.pt }
        width: 40 * chat.pt
        height: width
        radius: width / 2
        color: Qt.alpha(chat.barFill, 0.94)
        border { width: 1; color: chat.hairline }
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.8
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Components.Icon {
            anchors { centerIn: parent; verticalCenterOffset: 1 * chat.pt }
            width: 22 * chat.pt
            height: width
            action: "down"
            iconColor: chat.secondaryInk
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: history.goToBottom()
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
        height: field.height + 16 * chat.pt + (draft.visible ? draft.height + 6 * chat.pt : 0)
            + (pasteNotice.visible ? pasteNotice.height + 4 * chat.pt : 0)
        color: chat.barFill

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: chat.hairline
        }

        Rectangle {
            id: draft
            visible: chat.attachment !== null
            anchors { top: parent.top; topMargin: 8 * chat.pt; left: field.left; right: field.right }
            height: 52 * chat.pt
            radius: 12 * chat.pt
            color: chat.fieldFill

            Image {
                id: draftImage
                visible: chat.attachment?.kind === "image"
                source: visible ? chat.attachment.url : ""
                anchors { left: parent.left; leftMargin: 6 * chat.pt; verticalCenter: parent.verticalCenter }
                width: height
                height: 40 * chat.pt
                sourceSize.width: 160
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Components.Icon {
                visible: !draftImage.visible
                anchors.centerIn: draftImage
                width: 24 * chat.pt
                height: width
                action: "record"
                iconColor: chat.link
            }
            Text {
                anchors { left: draftImage.right; leftMargin: 8 * chat.pt; verticalCenter: parent.verticalCenter }
                text: draftImage.visible ? "Image attached" : "Recording attached"
                color: chat.ink
                font { family: Theme.Fonts.family; pixelSize: 14 * chat.pt }
            }
            MouseArea {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 40 * chat.pt
                height: parent.height
                cursorShape: Qt.PointingHandCursor
                onClicked: { chat.removeAttachment(); chat.focusPage() }
                Components.Icon {
                    anchors.centerIn: parent
                    width: 16 * chat.pt
                    height: width
                    action: "close"
                    iconColor: chat.secondaryInk
                }
            }
        }

        Text {
            id: pasteNotice
            visible: chat.pasteError !== ""
            anchors { bottom: field.top; bottomMargin: 4 * chat.pt; left: field.left; right: parent.right; rightMargin: 10 * chat.pt }
            text: chat.pasteError
            color: "#ffb4a7"
            wrapMode: Text.Wrap
            font { family: Theme.Fonts.family; pixelSize: 12 * chat.pt }
        }

        Rectangle {
            id: field
            anchors { left: parent.left; leftMargin: 12 * chat.pt; right: sendButton.left; rightMargin: 8 * chat.pt; bottom: parent.bottom; bottomMargin: 8 * chat.pt }
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
                    Keys.onPressed: event => {
                        if (event.matches(StandardKey.Copy) && !composer.selectedText && chat.selectedMessage) {
                            event.accepted = true
                            chat.selectedMessage.copy()
                            return
                        }
                        if (!event.matches(StandardKey.Paste)) return
                        event.accepted = true
                        if (clipboard.running) return
                        chat.pasteError = ""
                        clipboard.running = true
                    }
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
            readonly property bool ready: chat.readyToSend
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
