import QtQuick
import "../Components" as Components
import "../Theme" as Theme

Rectangle {
    id: root

    required property var notification
    implicitHeight: content.implicitHeight + 24
    radius: 8
    color: Theme.Colors.activeWorkspace

    Components.IconButton {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        z: 1
        width: 24
        height: 24
        iconSize: 14
        icon: "close"
        tooltip: "Dismiss notification"
        onClicked: { if (root.notification) root.notification.dismiss() }
    }

    Column {
        id: content
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 6

        Row {
            id: message
            width: parent.width
            spacing: 12

            Image {
                id: thumbnail
                width: 64
                height: 64
                source: root.notification ? root.notification.image : ""
                sourceSize.width: 160
                sourceSize.height: 160
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                visible: source.toString().length > 0 && status !== Image.Error
            }

            Column {
                width: message.width - (thumbnail.visible ? thumbnail.width + message.spacing : 0)
                spacing: 6

                Text {
                    width: parent.width - 28
                    text: root.notification ? root.notification.summary : ""
                    textFormat: Text.PlainText
                    color: Theme.Colors.foreground
                    font.pixelSize: 14
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.notification ? root.notification.body : ""
                    textFormat: Text.PlainText
                    visible: text.length > 0
                    color: Theme.Colors.foreground
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.notification ? root.notification.appName : ""
                    textFormat: Text.PlainText
                    visible: text.length > 0
                    elide: Text.ElideRight
                    color: Theme.Colors.foreground
                    opacity: 0.65
                    font.pixelSize: 11
                }
            }
        }

        Flow {
            x: thumbnail.visible ? thumbnail.width + message.spacing : 0
            width: parent.width - x
            spacing: 6
            visible: children.length > 0

            Repeater {
                model: root.notification ? root.notification.actions : []

                Rectangle {
                    id: actionButton
                    required property var modelData
                    width: Math.min(actionText.implicitWidth + 20, parent.width)
                    height: 28
                    radius: 6
                    color: Theme.Colors.background
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.text
                    Keys.onReturnPressed: modelData.invoke()
                    Keys.onSpacePressed: modelData.invoke()

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 20)
                        text: actionButton.modelData.text
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Colors.foreground
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: actionButton.modelData.invoke()
                    }
                }
            }
        }
    }
}
