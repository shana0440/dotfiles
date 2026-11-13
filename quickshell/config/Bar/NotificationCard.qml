import QtQuick
import Quickshell.Widgets
import "../Components" as Components
import "../Theme" as Theme
import "../Services" as Services

// A notification in the list, styled like the open Ding toast it came from: status
// icon, title with the app as trailing meta, a quieter description, and Ding's
// primary and secondary buttons.
Rectangle {
    id: root

    required property var notification
    readonly property string status: notification ? Services.Notifications.statusOf(notification) : "info"
    // As in the toast, an image takes the icon's place, except a capture's, which
    // shows in full under the text.
    readonly property bool imageReady: picture.status === Image.Ready
    readonly property bool showsPreview: status === "success" && imageReady

    implicitHeight: content.implicitHeight + 24
    radius: 16
    color: Theme.Colors.surface
    border.width: 1
    border.color: Theme.Colors.ring

    Components.IconButton {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        z: 1
        width: 24
        height: 24
        radius: 12
        iconSize: 12
        icon: "close"
        tooltip: "Dismiss notification"
        onClicked: { if (root.notification) root.notification.dismiss() }
    }

    Row {
        id: content
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 10

        Item {
            width: 28
            height: 28

            ClippingRectangle {
                anchors.fill: parent
                radius: 14
                color: Theme.Colors.background
                border.width: 1
                border.color: Theme.Colors.ring
                visible: root.imageReady && !root.showsPreview

                Image {
                    id: picture
                    anchors.fill: parent
                    source: root.notification ? root.notification.image : ""
                    // The icon provider (image://icon) needs both dimensions; it keeps the aspect.
                    sourceSize: Qt.size(56, 56)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                }
            }

            Components.StatusIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                animated: false
                visible: !root.imageReady || root.showsPreview
                status: root.status
            }
        }

        Column {
            width: content.width - 38
            spacing: 4

            Row {
                width: parent.width - 28
                spacing: 6

                Text {
                    id: title
                    width: Math.min(implicitWidth, parent.width - (app.text.length > 0 ? app.width + 6 : 0))
                    text: root.notification ? root.notification.summary : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.Colors.foreground
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    id: app
                    anchors.baseline: title.baseline
                    width: Math.min(implicitWidth, 120)
                    text: root.notification ? root.notification.appName : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.Colors.foreground
                    opacity: 0.7
                    font.pixelSize: 12
                }
            }

            Text {
                width: parent.width
                text: root.notification ? root.notification.body : ""
                textFormat: Text.PlainText
                visible: text.length > 0
                color: Theme.Colors.foreground
                opacity: 0.65
                font.pixelSize: 13
                wrapMode: Text.Wrap
                maximumLineCount: 6
                elide: Text.ElideRight
            }

            ClippingRectangle {
                width: Math.min(parent.width, 240)
                // Collapsed rather than hidden: a clipping surface created hidden never paints.
                height: root.showsPreview
                    ? Math.min(width * (picture.implicitWidth > 0 ? picture.implicitHeight / picture.implicitWidth : 0.5625), 160) : 0
                radius: 10
                color: Theme.Colors.background
                border.width: 1
                border.color: Theme.Colors.ring

                Image {
                    anchors.fill: parent
                    source: picture.source
                    sourceSize: Qt.size(480, 480)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                }
            }

            Flow {
                width: parent.width
                spacing: 6
                topPadding: 4
                visible: actions.count > 0

                Repeater {
                    id: actions
                    model: root.notification ? root.notification.actions : []

                    Rectangle {
                        id: actionButton
                        required property var modelData
                        required property int index
                        readonly property bool primary: index === 0
                        width: Math.min(actionText.implicitWidth + (primary ? 28 : 20), parent.width)
                        height: 30
                        radius: 15
                        color: primary
                            ? (mouse.containsMouse ? Qt.tint(Theme.Colors.foreground, "#2e0c0c0d") : Theme.Colors.foreground)
                            : mouse.containsMouse || activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
                        scale: mouse.pressed ? 0.96 : 1
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.text
                        Keys.onReturnPressed: Services.Notifications.invokeAction(root.notification, modelData)
                        Keys.onSpacePressed: Services.Notifications.invokeAction(root.notification, modelData)

                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 20)
                            text: actionButton.modelData.text
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: actionButton.primary ? Theme.Colors.background : Theme.Colors.foreground
                            opacity: actionButton.primary || mouse.containsMouse ? 1 : 0.65
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.Notifications.invokeAction(root.notification, actionButton.modelData)
                        }
                    }
                }
            }
        }
    }
}
