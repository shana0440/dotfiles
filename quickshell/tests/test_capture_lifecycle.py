"""Exercise the real Quickshell service with isolated, deliberately delayed helpers."""
import shutil
import subprocess
import time
import unittest

from offscreen_quickshell import offscreen_shell, read_until

MOCK = '''
import json
import os
from pathlib import Path
import sys
import time

state = Path(os.environ["QUICKSHELL_TEST_STATE"])
command = Path(sys.argv[0]).name
if command == "hypr-screenshot":
    counter = state / "screenshots"
    number = int(counter.read_text()) + 1 if counter.exists() else 1
    counter.write_text(str(number))
    time.sleep(0.2)
    if number % 2 == 0:
        sys.exit(1)
    path = state / "saved.png"
    path.write_bytes(b"synthetic screenshot")
    print(path, flush=True)
elif sys.argv[1] == "status":
    path = state / "recording.json"
    status = path.read_text() if path.exists() else json.dumps({"mode": "none", "startedAtSeconds": 0, "geometry": ""})
    # Read before waiting: this stale query must not retire the pending outline.
    time.sleep(0.7)
    print(status)
elif sys.argv[1] == "region":
    counter = state / "starts"
    number = int(counter.read_text()) + 1 if counter.exists() else 1
    counter.write_text(str(number))
    time.sleep(0.15)
    if number % 2 == 0:
        sys.exit(1)
    (state / "recording.json").write_text(json.dumps({"mode": "region", "startedAtSeconds": int(time.time()), "geometry": sys.argv[3]}))
elif sys.argv[1] == "stop":
    (state / "recording.json").unlink(missing_ok=True)
'''


@unittest.skipUnless(shutil.which("quickshell"), "requires Quickshell")
class CaptureLifecycleTests(unittest.TestCase):
    def test_feedback_and_continuous_recording_outline(self):
        commands = {"hypr-screenshot": MOCK, "hypr-record": MOCK}
        with offscreen_shell("CaptureLifecycle.qml", commands) as (directory, config, environment, process):
            output = ""
            for generation in range(3):
                if generation:
                    service = config / "Services/Capture.qml"
                    replacement = service.with_suffix(".qml.new")
                    replacement.write_text(service.read_text() + "\n// Atomic replacement reload test.\n")
                    replacement.replace(service)
                    subprocess.run(
                        [shutil.which("quickshell"), "--path", str(config), "ipc", "call", "captureTest", "reloadShell"],
                        env=environment, check=True, capture_output=True, text=True, timeout=3,
                    )
                generation_output = read_until(process, "CAPTURE_TEST_")
                output += generation_output
                self.assertIn("CAPTURE_TEST_PASS", generation_output, output)
                self.assertNotIn("CAPTURE_TEST_FAIL", generation_output, output)
                ready_deadline = time.monotonic() + 3
                while True:
                    response = subprocess.run(
                        [shutil.which("quickshell"), "--path", str(config), "ipc", "call", "captureTest", "ready"],
                        env=environment, capture_output=True, text=True, timeout=3,
                    )
                    if response.stdout.strip() == "true" or time.monotonic() >= ready_deadline:
                        break
                    time.sleep(0.05)
                self.assertEqual(response.returncode, 0, response.stderr)
                self.assertEqual(response.stdout.strip(), "true", output + response.stderr)
                handlers = subprocess.check_output(
                    [shutil.which("quickshell"), "--path", str(config), "ipc", "show"],
                    env=environment, text=True, timeout=3,
                )
                self.assertIn("target screenshots", handlers)
            self.assertEqual((directory / "starts").read_text(), "6")
            self.assertEqual((directory / "screenshots").read_text(), "6")


if __name__ == "__main__":
    unittest.main()
