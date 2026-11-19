import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
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

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool pickingInput: shownPage === "input"
    readonly property var connectedBluetooth: Services.Bluetooth.connectedDevices

    implicitWidth: 480
    implicitHeight: page === "bluetooth" ? bluetoothView.implicitHeight
        : page === "wifi" ? wifiView.implicitHeight
        : page ? Math.min(maximumHeight, pageHeader.height + 12 + devicePage.implicitHeight + 40)
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

    function devices(input) {
        return Pipewire.nodes.values.filter(node => node.audio && node.isSink !== input && !node.isStream)
    }

    function labelOf(node) {
        return node ? node.description || node.nickname || node.name : ""
    }

    function select(input, node) {
        if (input)
            Pipewire.preferredDefaultAudioSource = node
        else
            Pipewire.preferredDefaultAudioSink = node
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

    WifiController {
        id: wifiState
        active: root.active
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => node)
    }

    Components.Spring {
        id: pageSpring
        to: root.page ? 1 : 0
        stiffness: Theme.Motion.stackStiffness
        damping: Theme.Motion.stackDamping
        precision: 0.002
    }

    component Level: Item {
        id: level
        property var node: null
        property string icon: ""
        property string mutedIcon: ""
        property string what: ""
        readonly property var audio: node?.audio ?? null
        readonly property bool muted: audio?.muted ?? false
        readonly property real volume: audio?.volume ?? 0
        signal opened()

        function setVolume(value) {
            if (!audio)
                return
            audio.volume = Math.max(0, Math.min(1, value))
            audio.muted = false
        }

        width: parent.width
        height: 54

        Components.IconButton {
            id: mute
            x: -6
            anchors.verticalCenter: slider.verticalCenter
            width: 32
            height: 32
            iconSize: 16
            enabled: level.audio !== null
            icon: level.muted ? level.mutedIcon : level.icon
            iconColor: level.muted ? Theme.Colors.muted : Theme.Colors.foreground
            tooltip: level.muted ? "Unmute " + level.what : "Mute " + level.what
            onClicked: level.audio.muted = !level.audio.muted
        }

        Text {
            anchors.left: slider.left
            anchors.right: percent.right
            y: 32
            text: root.labelOf(level.node) || "No " + level.what + " device"
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.Colors.muted
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 11
        }

        Item {
            id: slider
            anchors.left: mute.right
            anchors.leftMargin: 6
            anchors.right: percent.left
            anchors.rightMargin: 12
            y: 4
            height: 24
            enabled: level.audio !== null

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Theme.Colors.track

                Rectangle {
                    width: track.width * Math.max(0, Math.min(1, level.volume))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.Colors.foreground
                    opacity: level.muted ? 0.35 : 1
                }
            }
            Rectangle {
                x: track.width * Math.max(0, Math.min(1, level.volume)) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: drag.pressed ? 16 : 14
                height: width
                radius: width / 2
                color: Theme.Colors.foreground
                visible: slider.enabled && !level.muted
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => level.setVolume(mouse.x / width)
                onPositionChanged: mouse => {
                    if (pressed)
                        level.setVolume(mouse.x / width)
                }
                onWheel: wheel => level.setVolume(level.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }

        Text {
            id: percent
            anchors.right: open.left
            anchors.rightMargin: 4
            anchors.verticalCenter: slider.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            text: level.audio ? (level.muted ? "Muted" : Math.round(level.volume * 100) + "%") : "—"
            color: level.muted ? Theme.Colors.muted : Theme.Colors.foreground
            font.family: level.muted ? Theme.Fonts.family : Theme.Fonts.mono
            font.weight: level.muted ? Theme.Fonts.weight : Font.Normal
            font.pixelSize: level.muted ? 12 : 13
        }

        Components.IconButton {
            id: open
            anchors.right: parent.right
            anchors.rightMargin: -6
            anchors.verticalCenter: slider.verticalCenter
            width: 32
            height: 32
            iconSize: 16
            icon: "forward"
            iconColor: Theme.Colors.muted
            tooltip: "Choose " + level.what
            onClicked: level.opened()
        }
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

        Rectangle {
            width: parent.width
            height: levels.implicitHeight + 16
            radius: 12
            color: Theme.Colors.surface

            Column {
                id: levels
                x: 16
                y: 8
                width: parent.width - 32

                Level {
                    node: root.sink
                    icon: "speaker"
                    mutedIcon: "speakerMuted"
                    what: "output"
                    onOpened: root.page = "output"
                }
                Level {
                    node: root.source
                    icon: "microphone"
                    mutedIcon: "microphoneMuted"
                    what: "input"
                    onOpened: root.page = "input"
                }
            }
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
        }
    }

    Item {
        x: 20 + 24 * (1 - pageSpring.value)
        y: 20
        width: parent.width - 40
        height: root.height - 40
        opacity: pageSpring.value
        visible: opacity > 0 && (root.shownPage === "output" || root.shownPage === "input")
        enabled: root.page === "output" || root.page === "input"

        Item {
            id: pageHeader
            width: parent.width
            height: 32

            Components.IconButton {
                id: back
                x: -6
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                iconSize: 18
                icon: "back"
                tooltip: "Back to settings"
                onClicked: root.page = ""
            }
            Column {
                anchors.left: back.right
                anchors.leftMargin: 2
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: root.pickingInput ? "Input" : "Output"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    width: parent.width
                    text: root.labelOf(root.pickingInput ? root.source : root.sink) || "Nothing selected"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }
            }
        }

        Flickable {
            x: -8
            y: pageHeader.height + 12
            width: parent.width + 16
            height: parent.height - y
            contentWidth: width
            contentHeight: devicePage.height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: devicePage
                readonly property var current: root.pickingInput ? root.source : root.sink
                readonly property var choices: root.devices(root.pickingInput)
                width: parent.width
                spacing: 2

                Text {
                    visible: devicePage.choices.length === 0
                    leftPadding: 12
                    text: !Pipewire.ready ? "Connecting to PipeWire" : root.pickingInput ? "No microphones" : "No output devices"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }

                Repeater {
                    model: devicePage.choices

                    Rectangle {
                        id: choice
                        required property var modelData
                        readonly property bool selected: devicePage.current === modelData
                        readonly property string label: root.labelOf(modelData)

                        width: parent.width
                        height: 36
                        radius: 8
                        color: rowMouse.containsMouse || activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
                        activeFocusOnTab: true
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: label
                        Accessible.checked: selected
                        Keys.onReturnPressed: root.select(root.pickingInput, modelData)
                        Keys.onSpacePressed: root.select(root.pickingInput, modelData)

                        Components.Icon {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            visible: choice.selected
                            action: "check"
                        }
                        Text {
                            x: 36
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 10
                            text: choice.label
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: choice.selected ? Theme.Colors.foreground : Theme.Colors.muted
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.select(root.pickingInput, choice.modelData)
                        }
                        Components.Tooltip {
                            text: choice.label
                            shown: rowMouse.containsMouse && choice.label.length > 40
                        }
                    }
                }
            }
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
