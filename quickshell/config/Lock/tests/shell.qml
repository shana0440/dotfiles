// Test shell: only the lock, locked at start. Never run it in your own session;
// run-headless.sh starts it as the root of a temporary config, inside a headless
// sway with a test PAM service.
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
