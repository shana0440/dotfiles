import QtQuick
import Quickshell.Widgets
import "../../Theme" as Theme

MouseArea {
    id: alert

    property real pt: 1
    property real hiddenBottom: 0
    property string title
    property string message
    property string error
    property string cancelLabel: "Cancel"
    property string confirmLabel
    property bool busy: false
    property bool shown: false
    signal confirmed
    signal dismissed

    function open() {
        error = ""
        shown = true
        forceActiveFocus()
    }
    function close() {
        if (busy) return
        shown = false
        dismissed()
    }

    anchors.fill: parent
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }
    onClicked: {}
    Keys.onEscapePressed: close()
    Keys.onReturnPressed: if (!busy) confirmed()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    ClippingRectangle {
        anchors { centerIn: parent; verticalCenterOffset: -alert.hiddenBottom / 2 }
        width: 270 * alert.pt
        height: texts.height + buttons.height
        radius: 14 * alert.pt
        color: Look.alertFill
        scale: alert.shown ? 1 : 1.15
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Column {
            id: texts
            width: parent.width
            topPadding: 19 * alert.pt
            bottomPadding: 19 * alert.pt
            spacing: 4 * alert.pt
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: alert.title
                color: Look.ink
                font { family: Theme.Fonts.family; weight: Font.DemiBold; pixelSize: 17 * alert.pt }
            }
            AlertText { text: alert.message; color: Look.ink }
            AlertText {
                visible: alert.error !== ""
                topPadding: 4 * alert.pt
                text: alert.error
                color: Look.destructive
            }
        }

        Rectangle {
            anchors.bottom: buttons.top
            width: parent.width
            height: 1
            color: Look.hairline
        }

        Row {
            id: buttons
            anchors.bottom: parent.bottom
            width: parent.width
            height: 44 * alert.pt
            AlertButton {
                label: alert.cancelLabel
                bold: true
                onClicked: alert.close()
            }
            Rectangle {
                width: 1
                height: parent.height
                color: Look.hairline
            }
            AlertButton {
                label: alert.confirmLabel
                tint: Look.destructive
                onClicked: alert.confirmed()
            }
        }
    }

    component AlertText: Text {
        x: 16 * alert.pt
        width: parent.width - 2 * x
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        font { family: Theme.Fonts.family; pixelSize: 13 * alert.pt }
    }

    component AlertButton: MouseArea {
        id: button
        property string label
        property color tint: Look.accent
        property bool bold: false
        width: (parent.width - 1) / 2
        height: parent.height
        enabled: !alert.busy
        cursorShape: Qt.PointingHandCursor
        Rectangle {
            anchors.fill: parent
            color: button.pressed ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        }
        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.tint
            opacity: button.enabled ? 1 : 0.5
            font { family: Theme.Fonts.family; weight: button.bold ? Font.DemiBold : Font.Normal; pixelSize: 17 * alert.pt }
        }
    }
}
