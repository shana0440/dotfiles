import QtQuick
import "../Theme" as Theme

Item {
    id: calendar

    signal closeRequested()

    property date today: new Date()
    property date displayedMonth: new Date(today.getFullYear(), today.getMonth(), 1)
    readonly property int firstWeekday: displayedMonth.getDay()

    function changeMonth(offset) {
        displayedMonth = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth() + offset, 1)
    }

    onVisibleChanged: {
        if (visible)
            displayedMonth = new Date(today.getFullYear(), today.getMonth(), 1)
    }

    implicitWidth: 280
    implicitHeight: 300

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.Colors.background

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Row {
                width: parent.width
                height: 28

                Text {
                    width: 28
                    height: parent.height
                    text: "‹"
                    color: Theme.Colors.foreground
                    font.pixelSize: 22
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendar.changeMonth(-1)
                    }
                }

                Text {
                    width: parent.width - 56
                    height: parent.height
                    text: Qt.formatDateTime(calendar.displayedMonth, "MMMM yyyy")
                    color: Theme.Colors.foreground
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendar.closeRequested()
                    }
                }

                Text {
                    width: 28
                    height: parent.height
                    text: "›"
                    color: Theme.Colors.foreground
                    font.pixelSize: 22
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendar.changeMonth(1)
                    }
                }
            }

            Row {
                id: weekdays
                width: parent.width
                height: 20

                Repeater {
                    model: 7

                    Text {
                        required property int index

                        width: weekdays.width / 7
                        height: weekdays.height
                        text: Qt.locale().standaloneDayName(index, Locale.ShortFormat)
                        color: Theme.Colors.foreground
                        opacity: 0.6
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Grid {
                id: days
                width: parent.width
                columns: 7
                rowSpacing: 4

                Repeater {
                    model: 42

                    Rectangle {
                        required property int index
                        readonly property date day: new Date(calendar.displayedMonth.getFullYear(),
                            calendar.displayedMonth.getMonth(), index - calendar.firstWeekday + 1)
                        readonly property bool isToday: day.toDateString() === calendar.today.toDateString()

                        width: days.width / 7
                        height: 32
                        radius: 4
                        color: isToday ? Theme.Colors.activeWorkspace : Theme.Colors.transparent

                        Text {
                            anchors.centerIn: parent
                            text: parent.day.getDate()
                            color: Theme.Colors.foreground
                            opacity: parent.day.getMonth() === calendar.displayedMonth.getMonth() ? 1 : 0.3
                            font.pixelSize: 13
                            font.bold: parent.isToday
                        }
                    }
                }
            }
        }
    }
}
