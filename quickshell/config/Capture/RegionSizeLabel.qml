import QtQuick
import "../Theme" as Theme

Rectangle {
    id: root

    property int regionWidth: 0
    property int regionHeight: 0
    property bool recording: false
    property bool showRecordButton: false
    signal recordRequested()
    readonly property string dimensions: regionWidth + " × " + regionHeight

    implicitWidth: content.implicitWidth + 16
    implicitHeight: content.implicitHeight + 12
    radius: 6
    color: Theme.Colors.background

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.dimensions
                color: Theme.Colors.foreground
                font.pixelSize: 12
            }

            Rectangle {
                objectName: "recordRegionButton"
                visible: root.showRecordButton
                width: recordLabel.implicitWidth + 24
                height: 28
                radius: 6
                color: Theme.Colors.accent
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Record selected region"
                Keys.onReturnPressed: root.recordRequested()
                Keys.onSpacePressed: root.recordRequested()

                Text {
                    id: recordLabel
                    anchors.centerIn: parent
                    text: "Record"
                    color: Theme.Colors.background
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.recordRequested()
                }
            }
        }

        Text {
            visible: root.recording
            text: "Enter to record · Esc to cancel"
            color: Theme.Colors.foreground
            opacity: 0.65
            font.pixelSize: 11
        }
    }
}
