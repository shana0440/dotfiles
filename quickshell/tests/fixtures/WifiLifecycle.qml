import QtQuick
import Quickshell
import "Bar" as Bar

ShellRoot {
    Bar.WifiMenu {
        id: wifi
        active: true
        onConnectionChanged: verificationDelay.start()
    }

    Timer {
        interval: 250
        running: true
        onTriggered: wifi.selectNetwork("Guest", "--")
    }

    Timer {
        id: verificationDelay
        interval: 750
        onTriggered: console.log("WIFI_TEST_DONE")
    }
}
