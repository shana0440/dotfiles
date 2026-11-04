import QtQuick
import "../Components" as Components
import "../Theme" as Theme

Rectangle {
    id: root

    required property var notification
    implicitHeight: content.implicitHeight + 24
    radius: 8
    color: Theme.Colors.activeWorkspace

    Column {
        id: content
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 6

        Item {
            width: parent.width
            height: 24

            Text {
                anchors.left: parent.left
                anchors.right: dismiss.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.notification ? root.notification.appName : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.Colors.foreground
                opacity: 0.65
                font.pixelSize: 11
            }

            Components.IconButton {
                id: dismiss
                anchors.right: parent.right
                width: 24
                height: 24
                iconSize: 14
                icon: "close"
                tooltip: "Dismiss notification"
                onClicked: { if (root.notification) root.notification.dismiss() }
            }
        }

        Text {
            width: parent.width
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

        Flow {
            width: parent.width
            spacing: 6
            visible: children.length > 0

            Repeater {
                model: root.notification ? root.notification.actions : []

                Rectangle {
                    id: actionButton
                    required property var modelData
                    width: Math.min(actionText.implicitWidth + 20, content.width)
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
