import QtQuick
import Quickshell.Bluetooth
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    property bool active: false
    property int maximumHeight: 560
    property string page: ""
    property string shownPage: ""
    signal closeRequested()

    readonly property var connectedBluetooth: Services.Bluetooth.connectedDevices

    implicitWidth: 480
    implicitHeight: page === "bluetooth" ? bluetoothView.implicitHeight
        : page === "inputMethod" ? inputMethodPage.implicitHeight
        : page === "wifi" ? wifiView.implicitHeight
        : home.implicitHeight + 40
    clip: true

    onPageChanged: if (page) shownPage = page
    onActiveChanged: page = ""

    function navigateBack() {
        page = ""
    }

    function navigateForward() {
        page = shownPage
    }

    function bluetoothStatus() {
        if (!Services.Bluetooth.available)
            return "Unavailable"
        if (Services.Bluetooth.adapter.state === BluetoothAdapterState.Blocked)
            return "Blocked"
        if (!Services.Bluetooth.enabled)
            return "Off"
        if (connectedBluetooth.length === 1)
            return connectedBluetooth[0].name
        if (connectedBluetooth.length > 1)
            return connectedBluetooth.length + " devices"
        return "On"
    }

    InputMethodState {
        id: inputMethod
    }

    WifiController {
        id: wifiState
        active: root.active
    }

    Components.Spring {
        id: pageSpring
        to: root.page ? 1 : 0
        stiffness: Theme.Motion.stackStiffness
        damping: Theme.Motion.stackDamping
        precision: 0.002
    }

    component Tile: Rectangle {
        id: tile
        property string icon: ""
        property string title: ""
        property string detail: ""
        property bool on: false
        property string toggleLabel: ""
        property string openLabel: ""
        signal toggled()
        signal opened()

        height: 60
        radius: 12
        color: Theme.Colors.surface

        Rectangle {
            id: toggleArea
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: tile.openLabel ? divider.left : parent.right
            anchors.margins: 4
            radius: 8
            color: toggleMouse.containsMouse || activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
            opacity: tile.enabled ? 1 : 0.4
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: tile.toggleLabel
            Keys.onReturnPressed: tile.toggled()
            Keys.onSpacePressed: tile.toggled()

            Rectangle {
                id: badge
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16
                color: tile.on ? Theme.Colors.foreground : Theme.Colors.track

                Components.Icon {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    action: tile.icon
                    iconColor: tile.on ? Theme.Colors.background : Theme.Colors.foreground
                }
            }
            Column {
                anchors.left: badge.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: tile.title
                    elide: Text.ElideRight
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 13
                }
                Text {
                    width: parent.width
                    text: tile.detail
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }
            }
            MouseArea {
                id: toggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.toggled()
            }
            Components.Tooltip {
                text: tile.toggleLabel
                shown: toggleMouse.containsMouse
            }
        }

        Rectangle {
            id: divider
            anchors.right: openButton.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 28
            visible: tile.openLabel.length > 0
            color: Theme.Colors.ring
        }

        Components.IconButton {
            id: openButton
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: tile.openLabel ? 36 : 0
            height: 52
            visible: tile.openLabel.length > 0
            iconSize: 16
            icon: "forward"
            iconColor: Theme.Colors.muted
            tooltip: tile.openLabel
            onClicked: tile.opened()
        }
    }

    Column {
        id: home
        x: 20 - 24 * pageSpring.value
        y: 20
        width: parent.width - 40
        spacing: 12
        opacity: 1 - pageSpring.value
        visible: opacity > 0
        enabled: !root.page

        Text {
            text: "Settings"
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.pixelSize: 16
            font.bold: true
        }

        Grid {
            id: tiles
            readonly property real tileWidth: (width - columnSpacing) / 2
            width: parent.width
            columns: 2
            columnSpacing: 12
            rowSpacing: 12

            Tile {
                width: tiles.tileWidth
                icon: !wifiState.enabled ? "wifiOff"
                    : !wifiState.current || wifiState.current.strength >= 67 ? "wifi"
                    : wifiState.current.strength >= 34 ? "wifiHigh" : "wifiLow"
                title: "Wi-Fi"
                detail: !wifiState.loaded ? "Checking" : !wifiState.enabled ? "Off" : wifiState.current?.ssid ?? "On"
                on: wifiState.enabled
                toggleLabel: wifiState.enabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
                openLabel: "Wi-Fi networks"
                onToggled: wifiState.setEnabled(!wifiState.enabled)
                onOpened: root.page = "wifi"
            }
            Tile {
                width: tiles.tileWidth
                icon: !Services.Bluetooth.enabled ? "bluetoothOff"
                    : root.connectedBluetooth.length > 0 ? "bluetoothConnected" : "bluetooth"
                title: "Bluetooth"
                detail: root.bluetoothStatus()
                on: Services.Bluetooth.enabled
                enabled: Services.Bluetooth.available
                    && Services.Bluetooth.adapter.state !== BluetoothAdapterState.Blocked
                toggleLabel: Services.Bluetooth.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on"
                openLabel: "Bluetooth devices"
                onToggled: Services.Bluetooth.setEnabled(!Services.Bluetooth.enabled)
                onOpened: root.page = "bluetooth"
            }
            Tile {
                width: tiles.tileWidth
                icon: Theme.Colors.transparentTheme ? "themeTransparent" : "themeDark"
                title: "Theme"
                detail: Theme.Colors.transparentTheme ? "Transparent" : "Dark"
                on: Theme.Colors.transparentTheme
                toggleLabel: Theme.Colors.transparentTheme ? "Use dark theme" : "Use transparent theme"
                onToggled: Theme.Colors.toggleTheme()
            }
            Tile {
                width: tiles.tileWidth
                icon: Services.Notifications.doNotDisturb ? "notificationsOff" : "notifications"
                title: "Do Not Disturb"
                detail: Services.Notifications.doNotDisturb ? "Pop-ups hidden" : "Off"
                on: Services.Notifications.doNotDisturb
                toggleLabel: Services.Notifications.doNotDisturb ? "Show notification pop-ups" : "Hide notification pop-ups"
                onToggled: Services.Notifications.toggleDoNotDisturb()
            }
        }

        Rectangle {
            id: inputMethodRow
            width: parent.width
            height: 60
            radius: 12
            color: inputMethodMouse.containsMouse || activeFocus ? Theme.Colors.surfaceHover : Theme.Colors.surface
            border.width: activeFocus ? 2 : 0
            border.color: Theme.Colors.muted
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Input method, " + inputMethod.description
            Keys.onReturnPressed: root.page = "inputMethod"
            Keys.onSpacePressed: root.page = "inputMethod"

            Rectangle {
                id: inputMethodBadge
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16
                color: Theme.Colors.track

                Text {
                    anchors.centerIn: parent
                    text: inputMethod.label
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: text.length > 1 ? 11 : 14
                }
            }
            Column {
                anchors.left: inputMethodBadge.right
                anchors.leftMargin: 10
                anchors.right: inputMethodChevron.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Input method"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 13
                }
                Text {
                    width: parent.width
                    text: inputMethod.description
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }
            }
            Components.Icon {
                id: inputMethodChevron
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                action: "forward"
                iconColor: Theme.Colors.muted
            }
            MouseArea {
                id: inputMethodMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.page = "inputMethod"
            }
        }
    }

    NestedPage {
        id: inputMethodPage
        x: 24 * (1 - pageSpring.value)
        width: root.width
        maximumHeight: root.maximumHeight
        opacity: pageSpring.value
        visible: opacity > 0 && root.shownPage === "inputMethod"
        enabled: root.page === "inputMethod"
        title: "Input method"
        subtitle: inputMethod.description
        backPointed: inputMethodList.backPointed
        onBackRequested: root.page = ""

        InputMethodList {
            id: inputMethodList
            x: -8
            width: parent.width + 16
            active: root.active && root.page === "inputMethod"
            inputItem: inputMethod.inputItem
            onBackRequested: root.page = ""
        }
    }

    WifiView {
        id: wifiView
        x: 24 * (1 - pageSpring.value)
        width: root.width
        maximumHeight: root.maximumHeight
        wifi: wifiState
        opacity: pageSpring.value
        visible: opacity > 0 && root.shownPage === "wifi"
        enabled: root.page === "wifi"
        active: root.active && root.page === "wifi"
        onBackRequested: root.page = ""
        onCloseRequested: root.closeRequested()
    }

    BluetoothView {
        id: bluetoothView
        x: 24 * (1 - pageSpring.value)
        width: root.width
        maximumHeight: root.maximumHeight
        opacity: pageSpring.value
        visible: opacity > 0 && root.shownPage === "bluetooth"
        enabled: root.page === "bluetooth"
        active: root.active && root.page === "bluetooth"
        onBackRequested: root.page = ""
        onCloseRequested: root.closeRequested()
    }
}
