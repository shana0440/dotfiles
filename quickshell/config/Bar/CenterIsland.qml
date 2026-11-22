import QtQuick
import Quickshell
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Components.ExpandableIsland {
    id: root

    property string expandedView: "home"
    property bool volumeVisible: false
    property bool volumeShownElsewhere: false
    property int availableHeight: 560
    readonly property bool notificationVisible: Services.Notifications.previewVisible
    readonly property bool showingRecording: activeView === recordingView
    held: expanded || notificationVisible
    satellitesMerged: expanded || notificationVisible || volumeVisible || Services.Capture.recording
    readonly property bool keyboardFocusRequired: expanded && !dashboard.inputMethodsOpen

    activeView: {
        if (expanded)
            return dashboard
        if (Services.Notifications.previewVisible)
            return toast
        if (volumeVisible)
            return volumeSlider
        if (Services.Capture.recording)
            return recordingView
        return clockView
    }

    targetRadius: showingRecording ? recordingView.height / 2
        : activeView === toast ? Math.min(22, toast.height / 2)
        : Math.min(16, targetHeight / 2)

    function close() {
        if (expanded)
            expanded = false
        else
            Services.Notifications.hidePreview()
    }

    function open(view) {
        Services.Notifications.hidePreview()
        expandedView = view
        expanded = true
    }

    function openInputMethods() {
        open("settings")
        dashboard.showInputMethods()
    }

    function openBluetooth() {
        open("settings")
        dashboard.showBluetooth()
    }

    function cycleTab(step) {
        dashboard.cycle(step)
    }

    function moveFocus(forward) {
        dashboard.moveFocus(forward)
    }

    function focusSearch() {
        dashboard.focusSearch()
    }

    function typeIntoSearch(text) {
        return expanded && dashboard.typeIntoSearch(text)
    }

    Connections {
        target: Services.Notifications
        function onReceived() {
            root.volumeVisible = false
            volumeTimeout.stop()
        }
    }

    function showVolume() {
        if (volumeShownElsewhere)
            return
        expanded = false
        volumeVisible = true
        volumeTimeout.restart()
    }

    Timer {
        id: volumeTimeout
        interval: 1000
        onTriggered: {
            if (volumeSlider.interacting)
                restart()
            else
                root.volumeVisible = false
        }
    }

    Binding {
        target: Services.Notifications
        property: "held"
        value: root.expanded
    }

    Binding {
        target: Services.Notifications
        property: "listShown"
        value: root.expanded && root.expandedView === "notifications"
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    views: [
        Item {
            id: clockView
            readonly property bool pomodoroShown: Services.Pomodoro.running
            width: clockRow.implicitWidth + 24
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: clockMouse.containsMouse ? Theme.Colors.highlight : Theme.Colors.transparent
            }

            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.open("home")
            }

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    text: Qt.formatDateTime(clock.date, "ddd d MMM · hh:mm A")
                    color: Theme.Colors.foreground
                    font.pixelSize: 14
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: clockView.pomodoroShown
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    text: "·"
                    color: Theme.Colors.foreground
                    font.pixelSize: 14
                }
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: clockView.pomodoroShown
                    width: pomodoroRing.implicitWidth
                    height: pomodoroRing.implicitHeight

                    PomodoroRing {
                        id: pomodoroRing
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.open("pomodoro")
                    }
                }
            }
        },
        VolumeSlider {
            id: volumeSlider
            width: 280
            height: 32
            onAdjusted: root.showVolume()
        },
        Dashboard {
            id: dashboard
            tab: root.expandedView
            active: root.expanded
            today: clock.date
            maximumHeight: root.availableHeight
            onTabRequested: tab => root.open(tab)
            onCloseRequested: root.close()
        },
        RecordingView {
            id: recordingView
            elapsedSeconds: Services.Capture.recordingElapsedSeconds
        },
        DingToast {
            id: toast
            revealWidth: root.width
            revealHeight: root.height
            onListRequested: root.open("notifications")
            onGesture: kind => {
                if (kind === "error")
                    root.kick(380, 0)
                else if (kind === "repeat")
                    root.kick(0, 240)
            }
        }
    ]
}
