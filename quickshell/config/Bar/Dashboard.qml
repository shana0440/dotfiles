import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

// The expanded center island: tabs down the left, the selected page on the right.
Item {
    id: root

    property string tab: "calendar"
    property bool active: false
    property date today: new Date()
    property int maximumHeight: 560
    readonly property alias calendar: calendar
    readonly property Item currentPage: tab === "media" ? mediaView
        : tab === "audio" ? audioView
        : tab === "notifications" ? notificationList
        : tab === "network" ? networkView
        : tab === "bluetooth" ? bluetoothView
        : tab === "system" ? systemView
        : tab === "usage" ? usageView : calendarPage
    signal tabRequested(string tab)
    signal closeRequested()

    readonly property int sidebarWidth: 52

    // Every page shares one width so the tabs stay put while the height morphs.
    readonly property int pageWidth: calendarPage.implicitWidth

    width: sidebarWidth + 1 + pageWidth
    height: Math.max(tabs.implicitHeight + 16, currentPage.height)

    readonly property var tabList: [
        { tab: "calendar", icon: "calendar", tooltip: "Calendar" },
        { tab: "media", icon: "disc", tooltip: "Now playing" },
        { tab: "audio", icon: "speaker", tooltip: "Audio" },
        { tab: "notifications", icon: "notifications", tooltip: "Notifications" },
        { tab: "network", icon: "wifi", tooltip: "Network" },
        { tab: "bluetooth", icon: "bluetooth", tooltip: "Bluetooth" },
        { tab: "system", icon: "systemStatus", tooltip: "System" },
        { tab: "usage", icon: "usage", tooltip: "Usage" }
    ]

    // Moves to the next (1) or previous (-1) tab, wrapping around.
    function cycle(step) {
        const index = tabList.findIndex(entry => entry.tab === tab)
        tabRequested(tabList[(index + step + tabList.length) % tabList.length].tab)
    }

    // Scrolling over the tab rail moves one tab per notch; touchpads send small
    // steps that add up to a notch.
    // Above the tab buttons; it takes no buttons, so clicks and hover reach them.
    MouseArea {
        z: 1
        x: 0
        y: 0
        width: root.sidebarWidth
        height: root.height
        acceptedButtons: Qt.NoButton
        property real pending: 0
        onWheel: wheel => {
            pending += wheel.angleDelta.y
            while (Math.abs(pending) >= 120) {
                root.cycle(pending > 0 ? -1 : 1)
                pending -= pending > 0 ? 120 : -120
            }
        }
    }

    Column {
        id: tabs
        x: 8
        y: 8
        spacing: 4

        Repeater {
            model: root.tabList

            Components.IconButton {
                id: tabButton
                required property var modelData
                readonly property bool current: root.tab === modelData.tab

                icon: modelData.icon
                tooltip: modelData.tooltip
                selected: current
                iconColor: current ? Theme.Colors.foreground : Theme.Colors.muted
                activeFocusOnTab: false
                onClicked: root.tabRequested(modelData.tab)

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 7
                    width: 7
                    height: 7
                    radius: 4
                    color: Theme.Colors.info
                    visible: tabButton.modelData.tab === "notifications"
                        && Services.Notifications.count > 0
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 7
                    width: 7
                    height: 7
                    radius: 4
                    color: Theme.Colors.success
                    visible: tabButton.modelData.tab === "media" && Services.Media.playing
                }
            }
        }
    }

    Rectangle {
        x: root.sidebarWidth
        y: 8
        width: 1
        height: root.height - 16
        color: Theme.Colors.ring
    }

    Components.ViewStack {
        x: root.sidebarWidth + 1
        width: root.pageWidth
        height: root.height
        alignment: Qt.AlignLeft
        activeView: root.currentPage

        views: [
            Row {
                id: calendarPage

                Calendar {
                    id: calendar
                    today: root.today
                    onCloseRequested: root.closeRequested()
                }
                ClockFace {
                    active: root.active && root.tab === "calendar"
                }
            },
            MediaView {
                id: mediaView
                width: root.pageWidth
                active: root.active && root.tab === "media"
            },
            AudioView {
                id: audioView
                width: root.pageWidth
                maximumHeight: root.maximumHeight
            },
            NotificationView {
                id: notificationList
                width: root.pageWidth
                maximumHeight: root.maximumHeight
            },
            NetworkView {
                id: networkView
                width: root.pageWidth
                maximumHeight: root.maximumHeight
                active: root.active && root.tab === "network"
                onCloseRequested: root.closeRequested()
            },
            BluetoothView {
                id: bluetoothView
                width: root.pageWidth
                maximumHeight: root.maximumHeight
                active: root.active && root.tab === "bluetooth"
                onCloseRequested: root.closeRequested()
            },
            SystemView {
                id: systemView
                width: root.pageWidth
                active: root.active && root.tab === "system"
            },
            UsageView {
                id: usageView
                width: root.pageWidth
                active: root.active && root.tab === "usage"
            }
        ]
    }
}
