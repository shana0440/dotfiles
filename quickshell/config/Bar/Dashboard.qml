import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    property string tab: "home"
    property bool active: false
    property date today: new Date()
    property int maximumHeight: 560
    readonly property alias calendar: homeView.calendar
    readonly property bool inputMethodsOpen: tab === "home" && homeView.inputMethodsOpen
    readonly property Item currentPage: tab === "media" ? mediaView
        : tab === "audio" ? audioView
        : tab === "notifications" ? notificationList
        : tab === "network" ? networkView
        : tab === "bluetooth" ? bluetoothView
        : tab === "system" ? systemView
        : tab === "usage" ? usageView
        : tab === "pomodoro" ? pomodoroView
        : tab === "power" ? powerView : homeView
    signal tabRequested(string tab)
    signal closeRequested()

    readonly property int sidebarWidth: 52

    readonly property int pageWidth: homeView.implicitWidth
    readonly property string query: searchField.text
    readonly property int searchHeight: searchBar.visible ? searchBar.height + 8 : 0

    width: sidebarWidth + 1 + pageWidth
    height: searchHeight + Math.max(tabs.implicitHeight + 16, currentPage.height)

    onActiveChanged: if (!active) searchField.clear()

    readonly property var tabList: [
        { tab: "home", icon: "home", tooltip: "Home",
            keywords: ["calendar", "date", "weather", "input method", "keyboard", "theme"] },
        { tab: "media", icon: "disc", tooltip: "Now playing",
            keywords: ["media", "music", "song", "track", "player"] },
        { tab: "audio", icon: "speaker", tooltip: "Audio",
            keywords: ["volume", "sound", "speaker", "headphones", "microphone", "mic", "output", "input"] },
        { tab: "notifications", icon: "notifications", tooltip: "Notifications",
            keywords: ["alerts", "messages"] },
        { tab: "network", icon: "wifi", tooltip: "Network",
            keywords: ["wifi", "wi-fi", "wlan", "ethernet", "internet", "ssid", "connections"] },
        { tab: "bluetooth", icon: "bluetooth", tooltip: "Bluetooth",
            keywords: ["bt", "pair", "devices", "headphones"] },
        { tab: "system", icon: "systemStatus", tooltip: "System",
            keywords: ["cpu", "gpu", "memory", "ram", "vram", "storage", "disk"] },
        { tab: "usage", icon: "usage", tooltip: "Usage",
            keywords: ["claude", "codex", "agent", "limit", "quota"] },
        { tab: "pomodoro", icon: "timer", tooltip: "Pomodoro",
            keywords: ["timer", "focus", "break"] },
        { tab: "power", icon: "poweroff", tooltip: "Power",
            keywords: ["shutdown", "power off", "restart", "reboot", "lock", "log out", "logout"] }
    ]
    readonly property string normalizedQuery: query.trim().toLowerCase()
    readonly property var matchingTabs: normalizedQuery ? rankMatches(normalizedQuery) : tabList
    readonly property var shownTabs: tabList.filter(entry => matchingTabs.some(match => match.tab === entry.tab))

    onMatchingTabsChanged: {
        if (!normalizedQuery || matchingTabs.length === 0)
            return
        const best = matchingTabs[0]
        const current = tabList.find(entry => entry.tab === tab)
        if (matchRank(current, normalizedQuery) !== matchRank(best, normalizedQuery))
            tabRequested(best.tab)
    }

    function matchRank(entry, needle) {
        const names = [entry.tab, entry.tooltip.toLowerCase()]
        if (names.some(name => name.startsWith(needle)))
            return 0
        if (entry.keywords.some(keyword => keyword.startsWith(needle)))
            return 1
        if (names.concat(entry.keywords).some(term => term.includes(needle)))
            return 2
        return -1
    }

    function rankMatches(needle) {
        return tabList
            .map((entry, order) => ({ entry, order, rank: matchRank(entry, needle) }))
            .filter(match => match.rank >= 0)
            .sort((a, b) => a.rank - b.rank || a.order - b.order)
            .map(match => match.entry)
    }

    function showInputMethods() {
        homeView.inputMethodsOpen = true
    }

    function typeIntoSearch(text) {
        if (!query && !text.trim())
            return false
        searchField.insert(searchField.cursorPosition, text)
        searchField.forceActiveFocus()
        return true
    }

    function cycle(step) {
        if (shownTabs.length === 0)
            return
        const index = shownTabs.findIndex(entry => entry.tab === tab)
        tabRequested(shownTabs[(index + step + shownTabs.length) % shownTabs.length].tab)
    }

    Rectangle {
        id: searchBar
        x: 8
        y: 8
        width: root.width - 16
        height: 36
        radius: 8
        visible: root.query.length > 0
        color: Theme.Colors.background
        border.width: 1
        border.color: searchField.activeFocus ? Theme.Colors.muted : Theme.Colors.ring

        Components.Icon {
            id: searchIcon
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            action: "search"
            iconColor: Theme.Colors.muted
        }
        TextInput {
            id: searchField
            anchors.left: searchIcon.right
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 13
            clip: true
            Keys.onEscapePressed: clear()

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.matchingTabs.length === 0
                text: "No results"
                color: Theme.Colors.muted
                font.family: Theme.Fonts.family
                font.weight: Theme.Fonts.weight
                font.pixelSize: 12
            }
            onAccepted: clear()
            onTextChanged: if (!text) focus = false
        }
    }

    MouseArea {
        z: 1
        x: 0
        y: root.searchHeight
        width: root.sidebarWidth
        height: root.height - root.searchHeight
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

    MouseArea {
        z: 1
        x: root.sidebarWidth + 1
        y: root.searchHeight
        width: root.pageWidth
        height: root.height - root.searchHeight
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onPressed: mouse => {
            const page = root.currentPage
            if (mouse.button === Qt.BackButton && page.navigateBack)
                page.navigateBack()
            else if (mouse.button === Qt.ForwardButton && page.navigateForward)
                page.navigateForward()
        }
    }

    Column {
        id: tabs
        x: 8
        y: root.searchHeight + 8
        spacing: 4

        Repeater {
            model: root.tabList

            Components.IconButton {
                id: tabButton
                required property var modelData
                readonly property bool current: root.tab === modelData.tab

                visible: root.shownTabs.some(entry => entry.tab === modelData.tab)
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
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 7
                    width: 7
                    height: 7
                    radius: 4
                    color: Theme.Colors.foreground
                    visible: tabButton.modelData.tab === "pomodoro" && Services.Pomodoro.running
                }
            }
        }
    }

    Rectangle {
        x: root.sidebarWidth
        y: root.searchHeight + 8
        width: 1
        height: root.height - root.searchHeight - 16
        color: Theme.Colors.ring
    }

    Components.ViewStack {
        x: root.sidebarWidth + 1
        y: root.searchHeight
        width: root.pageWidth
        height: root.height - root.searchHeight
        alignment: Qt.AlignLeft
        activeView: root.currentPage

        views: [
            HomeView {
                id: homeView
                today: root.today
                active: root.active && root.tab === "home"
                onCloseRequested: root.closeRequested()
            },
            MediaView {
                id: mediaView
                width: root.pageWidth
                active: root.active && root.tab === "media"
            },
            AudioView {
                id: audioView
                width: root.pageWidth
                maximumHeight: root.maximumHeight - root.searchHeight
            },
            NotificationView {
                id: notificationList
                width: root.pageWidth
                maximumHeight: root.maximumHeight - root.searchHeight
            },
            NetworkView {
                id: networkView
                width: root.pageWidth
                maximumHeight: root.maximumHeight - root.searchHeight
                active: root.active && root.tab === "network"
                onCloseRequested: root.closeRequested()
            },
            BluetoothView {
                id: bluetoothView
                width: root.pageWidth
                maximumHeight: root.maximumHeight - root.searchHeight
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
            },
            PomodoroView {
                id: pomodoroView
                width: root.pageWidth
                active: root.active && root.tab === "pomodoro"
            },
            PowerView {
                id: powerView
                width: root.pageWidth
                fillHeight: tabs.implicitHeight + 16
                active: root.active && root.tab === "power"
                onCloseRequested: root.closeRequested()
            }
        ]
    }
}
