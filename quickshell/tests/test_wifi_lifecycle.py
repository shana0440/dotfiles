"""Verify post-connect refresh through real QML processes and a fake NetworkManager CLI."""
import json
import shutil
import unittest

from offscreen_quickshell import offscreen_shell, read_until

NMCLI = '''
import json
import os
from pathlib import Path
import sys

state = Path(os.environ["QUICKSHELL_TEST_STATE"])
active_file = state / "active-ssid"
active = active_file.read_text() if active_file.exists() else "Home"
if "list" in sys.argv:
    event = {"action": "scan", "active": active}
    for ssid in ("Home", "Guest"):
        print(("yes" if ssid == active else "no") + ":" + ssid + ":80:--:wlan0")
else:
    event = {"action": "connect", "ssid": sys.argv[-1]}
    active_file.write_text(sys.argv[-1])
with (state / "network-events.jsonl").open("a") as events:
    events.write(json.dumps(event) + "\\n")
'''


@unittest.skipUnless(shutil.which("quickshell"), "requires Quickshell")
class WifiLifecycleTests(unittest.TestCase):
    def test_successful_connection_refreshes_the_network_list(self):
        with offscreen_shell("WifiLifecycle.qml", {"nmcli": NMCLI}) as (directory, _, _, process):
            output = read_until(process, "WIFI_TEST_DONE", timeout=5)
            self.assertIn("WIFI_TEST_DONE", output, output)
            events = [json.loads(line) for line in (directory / "network-events.jsonl").read_text().splitlines()]
            self.assertEqual(events, [
                {"action": "scan", "active": "Home"},
                {"action": "connect", "ssid": "Guest"},
                {"action": "scan", "active": "Guest"},
            ])


if __name__ == "__main__":
    unittest.main()
