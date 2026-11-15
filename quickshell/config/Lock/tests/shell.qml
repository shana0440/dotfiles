import QtQuick
import Quickshell
import "Lock"

ShellRoot {
    Lock {
        id: lock
        pamConfig: "lock-test"
        pamDirectory: Quickshell.env("LOCK_TEST_PAM_DIR")
    }
    Timer {
        interval: 300
        running: true
        onTriggered: lock.lock()
    }
}
