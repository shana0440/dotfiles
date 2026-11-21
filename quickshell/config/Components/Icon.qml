import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme" as Theme

Item {
    id: root

    property string action: "poweroff"
    property color iconColor: Theme.Colors.foreground
    property bool filled: false
    readonly property string iconName: ({
        lock: "lock-keyhole",
        logout: "log-out",
        reboot: "rotate-cw",
        poweroff: "power",
        wifi: "wifi",
        wifiHigh: "wifi-high",
        wifiLow: "wifi-low",
        wifiOff: "wifi-off",
        bluetooth: "bluetooth",
        bluetoothOff: "bluetooth-off",
        bluetoothConnected: "bluetooth-connected",
        bluetoothSearching: "bluetooth-searching",
        audio: "audio-lines",
        microphone: "mic",
        previous: "skip-back",
        next: "skip-forward",
        play: "play",
        pause: "pause",
        close: "x",
        search: "search",
        settings: "settings",
        themeDark: "moon",
        themeTransparent: "lens",
        systemStatus: "activity",
        screenshot: "camera",
        screenshotRegion: "scan",
        screen: "monitor",
        window: "app-window",
        region: "square-dashed",
        record: "video",
        recordRegion: "square-dashed",
        pen: "pen-line",
        stop: "square",
        notifications: "bell",
        notificationsOff: "bell-off",
        home: "house",
        keyboard: "keyboard",
        disc: "disc-3",
        album: "disc-album",
        radio: "radio",
        ethernet: "ethernet-port",
        network: "globe",
        back: "chevron-left",
        forward: "chevron-right",
        down: "chevron-down",
        usage: "gauge",
        timer: "timer",
        reset: "rotate-ccw",
        speaker: "volume-2",
        speakerMuted: "volume-x",
        microphoneMuted: "mic-off",
        check: "check",
        checkDouble: "check-check",
        send: "arrow-up",
        remove: "trash",
        character: "user-pen",
        schedules: "calendar-clock",
        tasks: "hourglass",
        background: "image",
        backgroundApps: "layers",
        name: "id-card",
        clearNotifications: "list-x",
        weatherClear: "sun",
        weatherClearNight: "moon",
        weatherPartly: "cloud-sun",
        weatherPartlyNight: "cloud-moon",
        weatherCloudy: "cloud",
        weatherFog: "cloud-fog",
        weatherDrizzle: "cloud-drizzle",
        weatherRain: "cloud-rain",
        weatherSnow: "cloud-snow",
        weatherStorm: "cloud-lightning"
    })[action] ?? "power"
    readonly property string themedSvg: {
        const svg = svgTemplate.text().replace(/currentColor/g, iconColor.toString())
        return filled ? svg.replace(/fill="none"/g, 'fill="' + iconColor.toString() + '"') : svg
    }

    implicitWidth: 20
    implicitHeight: 20

    FileView {
        id: svgTemplate
        path: Quickshell.shellPath("Icons/lucide/" + root.iconName + ".svg")
        blockLoading: true
    }

    Image {
        anchors.fill: parent
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        source: "data:image/svg+xml;charset=utf-8," + encodeURIComponent(root.themedSvg)
    }
}
