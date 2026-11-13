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
        : tab === "notifications" ? notificationList
        : tab === "network" ? networkView
        : tab === "system" ? systemView : calendarPage
    signal tabRequested(string tab)
    signal closeRequested()

    readonly property int sidebarWidth: 52

    // Every page shares one width so the tabs stay put while the height morphs.
    readonly property int pageWidth: calendarPage.implicitWidth

    width: sidebarWidth + 1 + pageWidth
    height: Math.max(tabs.implicitHeight + 16, currentPage.height)

    Column {
        id: tabs
        x: 8
        y: 8
        spacing: 4

        Repeater {
            model: [
                { tab: "calendar", icon: "calendar", tooltip: "Calendar" },
                { tab: "media", icon: "disc", tooltip: "Now playing" },
                { tab: "notifications", icon: "notifications", tooltip: "Notifications" },
                { tab: "network", icon: "wifi", tooltip: "Network" },
                { tab: "system", icon: "systemStatus", tooltip: "System" }
            ]

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
            SystemView {
                id: systemView
                width: root.pageWidth
                active: root.active && root.tab === "system"
            }
        ]
    }
}
