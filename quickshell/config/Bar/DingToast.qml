import QtQuick
import QtQuick.Effects
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../Components" as Components
import "../Services" as Services
import "../Theme" as Theme

// The notification popup as a Ding toast (ding.yusufcengiz.dev) inside the center
// island: it arrives as a dot with its status icon, then springs open into a pill.
// The text is revealed by the island's live width, so the box and its content move
// together: it fades in, unblurs and slides out of the icon. A new notification
// morphs the open pill in place (the old text rolls up, the new one rolls in), a
// repeat counts up, and on close the text erases as the pill shrinks to its dot.
Item {
    id: root

    // The island's live size, which drives the reveal.
    property real revealWidth: width
    property real revealHeight: height
    // "enter" (a dot), "open" (the pill), "closing" (back to the dot) or "hidden".
    property string phase: "hidden"
    signal listRequested()
    // Content-aware motion for the island: "error" shakes, "repeat" nudges.
    signal gesture(string kind)

    readonly property int size: 44
    readonly property int copyMaximumWidth: 340
    readonly property var notification: Services.Notifications.preview
    readonly property bool visibleInIsland: Services.Notifications.previewVisible

    // Live content with the last values kept, so a notification closed by its sender
    // still has its text while the pill collapses.
    property string lastTitle: ""
    property string lastBody: ""
    property string lastApp: ""
    property string lastImage: ""
    property string lastStatus: "info"
    readonly property string title: notification?.summary ?? lastTitle
    readonly property string body: notification?.body ?? lastBody
    readonly property string app: notification?.appName ?? lastApp
    readonly property string image: notification?.image ?? lastImage
    // Critical is an error; a saved screenshot or recording (screen-capture's own
    // notification) is a success; everything else is info.
    readonly property string status: !notification ? lastStatus
        : notification.urgency === NotificationUrgency.Critical ? "error"
        : notification.desktopEntry === "screen-capture" ? "success" : "info"
    // A success shows its check: a capture preview cropped to a 28 px circle says
    // little, and the notification list shows it in full.
    readonly property bool showsImage: status !== "success" && picture.status === Image.Ready
    readonly property var actions: (notification?.actions ?? []).slice(0, 2)
    readonly property int count: Services.Notifications.previewCount
    readonly property bool sticky: Services.Notifications.previewDuration === 0
    onTitleChanged: if (notification) lastTitle = title
    onBodyChanged: if (notification) lastBody = body
    onAppChanged: if (notification) lastApp = app
    onImageChanged: if (notification) lastImage = image
    onStatusChanged: if (notification) lastStatus = status

    // The copy as it was before a change, for the roll (see `roll()`).
    property var shownCopy: ({ title: "", body: "" })
    function rememberCopy() { shownCopy = { title: root.title, body: root.body } }
    onLastTitleChanged: Qt.callLater(rememberCopy)
    onLastBodyChanged: Qt.callLater(rememberCopy)

    readonly property real fullWidth: Math.ceil((size + pill.width) / 2) * 2
    readonly property real fullHeight: Math.max(size, pill.height)
    width: phase === "open" ? fullWidth : size
    height: phase === "open" ? fullHeight : size

    // Reveal progress of the text (tp) and of the buttons (ap), from the island width.
    readonly property bool showingCopy: phase === "open" || phase === "closing"
    readonly property real copyEnd: buttonsBox.width > 0 ? size + copy.width + 8 : fullWidth
    readonly property real actionWidth: fullWidth - copyEnd
    readonly property real tp: showingCopy ? clamp((revealWidth - size) / Math.max(1, copyEnd - size)) : 0
    readonly property real ap: actionWidth > 2 ? clamp((revealWidth - copyEnd) / actionWidth) : clamp((tp - 0.45) / 0.55)
    function clamp(value) { return Math.max(0, Math.min(1, value)) }

    // The visible island's left edge inside this view: content grows out of the icon.
    readonly property real leftEdge: phase === "enter" ? 0 : (width - revealWidth) / 2

    onVisibleInIslandChanged: {
        if (visibleInIsland) {
            phase = "enter"
            statusIcon.restart()
            openTimer.restart()
        } else {
            openTimer.stop()
            phase = "hidden"
        }
    }

    Connections {
        target: Services.Notifications
        function onPreviewClosingChanged() {
            if (Services.Notifications.previewClosing) {
                openTimer.stop()
                root.phase = "closing"
            }
        }
        function onPreviewRestarted() {
            life.restart()
            if (root.phase !== "open")
                return
            if (Services.Notifications.previewCount > 1)
                root.gesture("repeat")
            else
                root.roll()
            root.react()
        }
    }

    // The dot arrives, then the pill opens.
    Timer {
        id: openTimer
        interval: 450
        onTriggered: {
            root.phase = "open"
            reactTimer.restart()
        }
    }
    Timer {
        id: reactTimer
        interval: 200
        onTriggered: root.react()
    }
    function react() {
        if (status === "error")
            gesture("error")
    }

    // The old copy rolls up and out while the new one rolls in.
    function roll() {
        ghost.title = shownCopy.title
        ghost.body = shownCopy.body
        rollOut.restart()
        rollIn.restart()
    }

    HoverHandler {
        onHoveredChanged: Services.Notifications.pausePreview(hovered)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.listRequested()
    }

    // Status icon, or the notification's image in its place.
    Item {
        id: icon
        x: root.leftEdge
        y: Math.min(0, (root.revealHeight - root.size) / 2)
        width: root.size
        height: root.size

        ClippingRectangle {
            id: avatar
            anchors.centerIn: parent
            width: 28
            height: 28
            radius: 14
            color: Theme.Colors.surface
            border.width: 1
            border.color: Theme.Colors.ring
            visible: root.showsImage

            Image {
                id: picture
                anchors.fill: parent
                source: root.image
                sourceSize.width: 56
                sourceSize.height: 56
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
        }

        Components.StatusIcon {
            id: statusIcon
            anchors.centerIn: parent
            width: 22
            height: 22
            visible: !root.showsImage
            status: root.status
        }
    }

    Row {
        id: pill
        x: root.leftEdge + root.size
        spacing: 8
        rightPadding: 8
        opacity: root.tp * 1.5 - 0.25
        transform: Translate { x: (1 - root.tp) * -12 }
        layer.enabled: root.tp > 0 && root.tp < 0.999
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 16
            blur: (1 - root.tp) * 10 / 16
        }

        Item {
            id: copy
            // Natural widths only: the lines size themselves from this.
            readonly property real titleWidth: titleText.implicitWidth
                + (root.count > 1 ? countText.implicitWidth + 6 : 0)
                + (root.app.length > 0 ? Math.min(metaText.implicitWidth, 120) + 6 : 0)
            width: Math.min(root.copyMaximumWidth, Math.max(titleWidth, root.body.length > 0 ? description.implicitWidth : 0)) + 6
            height: copyColumn.height + 24
            anchors.verticalCenter: parent.verticalCenter

            Column {
                id: copyColumn
                y: 12
                width: parent.width - 6
                spacing: 3
                opacity: 1
                transform: Translate { id: copyShift }

                Row {
                    id: titleLine
                    spacing: 6
                    width: Math.min(implicitWidth, copyColumn.width)

                    Text {
                        id: titleText
                        width: Math.min(implicitWidth, copyColumn.width
                            - (root.count > 1 ? countText.width + 6 : 0) - (root.app.length > 0 ? metaText.width + 6 : 0))
                        text: root.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Colors.foreground
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Text {
                        id: countText
                        visible: root.count > 1
                        width: root.count > 1 ? implicitWidth : 0
                        text: "×" + root.count
                        color: Theme.Colors.foreground
                        opacity: 0.7
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        id: metaText
                        visible: text.length > 0
                        width: root.app.length > 0 ? Math.min(implicitWidth, 120) : 0
                        text: root.app
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Colors.foreground
                        opacity: 0.7
                        font.pixelSize: 12
                    }
                }

                Text {
                    id: description
                    width: Math.min(implicitWidth, copyColumn.width)
                    visible: text.length > 0
                    text: root.body
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    lineHeight: 1.1
                    color: Theme.Colors.foreground
                    opacity: 0.65
                    font.pixelSize: 13
                }
            }

            // The previous copy, rolling up and out.
            Column {
                id: ghost
                property string title: ""
                property string body: ""
                y: 12
                width: copyColumn.width
                spacing: 3
                opacity: 0
                visible: opacity > 0
                transform: Translate { id: ghostShift }

                Text {
                    width: parent.width
                    text: ghost.title
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.Colors.foreground
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: ghost.body
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.Colors.foreground
                    opacity: 0.65
                    font.pixelSize: 13
                }
            }

            ParallelAnimation {
                id: rollOut
                NumberAnimation { target: ghost; property: "opacity"; from: 1; to: 0; duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }
                NumberAnimation { target: ghostShift; property: "y"; from: 0; to: -12; duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }
            }
            ParallelAnimation {
                id: rollIn
                NumberAnimation { target: copyColumn; property: "opacity"; from: 0; to: 1; duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }
                NumberAnimation { target: copyShift; property: "y"; from: 12; to: 0; duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }
            }
        }

        // Buttons appear as the width reaches them. The fade lives on an inner row so
        // it never feeds back into the layout it is derived from.
        Item {
            id: buttonsBox
            anchors.verticalCenter: parent.verticalCenter
            width: buttons.implicitWidth
            height: buttons.implicitHeight

            Row {
                id: buttons
                spacing: 8
                opacity: root.ap * 1.3 - 0.15
                scale: 0.85 + root.ap * 0.15
    
                Repeater {
                    model: root.actions
    
                    Rectangle {
                        id: action
                        required property var modelData
                        required property int index
                        readonly property bool primary: index === 0
                        width: actionLabel.implicitWidth + (primary ? 28 : 20)
                        height: 30
                        radius: 15
                        color: primary
                            ? (actionMouse.containsMouse ? Qt.tint(Theme.Colors.foreground, "#2e0c0c0d") : Theme.Colors.foreground)
                            : actionMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent
                        scale: actionMouse.pressed ? 0.96 : 1
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.text
                        Keys.onReturnPressed: Services.Notifications.invokeAction(root.notification, modelData)
                        Keys.onSpacePressed: Services.Notifications.invokeAction(root.notification, modelData)
    
                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: action.modelData.text
                            textFormat: Text.PlainText
                            color: action.primary ? Theme.Colors.background : Theme.Colors.foreground
                            opacity: action.primary || actionMouse.containsMouse ? 1 : 0.65
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
    
                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.Notifications.invokeAction(root.notification, action.modelData)
                        }
                    }
                }
    
                // Only popups that wait to be dismissed carry a close button, as in Ding.
                Components.IconButton {
                    visible: root.sticky
                    width: 30
                    height: 30
                    radius: 15
                    iconSize: 12
                    icon: "close"
                    tooltip: "Hide notification"
                    onClicked: Services.Notifications.dismissPreview()
                }
            }
        }
    }

    // Countdown line along the bottom edge, held while hovered. Inset so it stays
    // inside the pill's rounded ends.
    Rectangle {
        readonly property real cornerRadius: Math.min(22, root.height / 2)
        readonly property real inset: cornerRadius - Math.sqrt(Math.max(0, cornerRadius * cornerRadius - (cornerRadius - 1) * (cornerRadius - 1)))
        x: root.leftEdge + inset
        y: Math.min(root.height, root.revealHeight) - 2
        width: Math.max(0, (root.phase === "enter" ? root.size : root.revealWidth) - 2 * inset)
        height: 2
        visible: !root.sticky && root.phase === "open"
        color: Theme.Colors.status(root.status)
        opacity: 0.45 * root.tp
        transform: Scale { xScale: life.progress }
    }

    QtObject {
        id: life
        property real progress: 1
        function restart() {
            countdown.stop()
            progress = 1
            if (!root.sticky) {
                countdown.duration = Services.Notifications.previewDuration
                countdown.start()
            }
        }
    }
    NumberAnimation {
        id: countdown
        target: life
        property: "progress"
        from: 1
        to: 0
        paused: running && Services.Notifications.previewPaused
    }
}
