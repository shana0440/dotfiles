"""Accepted screenshot requests must run in order, including after a failed job."""
import json
import shutil
import subprocess
import unittest

from offscreen_quickshell import offscreen_shell, read_until

SCREENSHOT = '''
import json
import os
from pathlib import Path
import sys
import time

state = Path(os.environ["QUICKSHELL_TEST_STATE"])
counter = state / "capture-count"
number = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(number))

def record(event):
    with (state / "capture-events.jsonl").open("a") as output:
        output.write(json.dumps({"job": number, "event": event}) + "\\n")

record("started")
time.sleep(0.2)
if sys.argv[1] == "fail":
    record("failed")
    sys.exit(1)
path = state / ("screenshot-" + str(number) + ".png")
path.write_bytes(b"synthetic screenshot")
record("saved")
print(path, flush=True)
time.sleep(0.05)  # Clipboard delivery must finish before the next job starts.
record("finished")
'''
STATUS = 'print(\'{"mode":"none","startedAtSeconds":0,"geometry":""}\')'


@unittest.skipUnless(shutil.which("quickshell"), "requires Quickshell")
class ScreenshotQueueTests(unittest.TestCase):
    def test_rapid_screenshots_are_all_saved_in_order(self):
        self.check_queue(middle="full", saved_jobs=[1, 2, 3], executed_jobs=3)

    def test_queue_continues_after_capture_failure(self):
        self.check_queue(middle="fail", saved_jobs=[1, 3], executed_jobs=3)

    def test_queue_continues_when_a_helper_cannot_start(self):
        self.check_queue(middle="missing", saved_jobs=[1, 2], executed_jobs=2)

    def check_queue(self, *, middle, saved_jobs, executed_jobs):
        commands = {"hypr-screenshot": SCREENSHOT, "hypr-record": STATUS}
        with offscreen_shell("ScreenshotQueue.qml", commands) as (directory, config, environment, process):
            output = read_until(process, "Configuration Loaded")
            self.assertIn("Configuration Loaded", output, output)
            response = subprocess.run(
                [shutil.which("quickshell"), "--path", str(config), "ipc", "call", "queueTest", "submit",
                 middle],
                env=environment, capture_output=True, text=True, timeout=3,
            )
            self.assertEqual(response.returncode, 0, response.stderr)
            output += read_until(process, "SCREENSHOT_QUEUE_DONE", timeout=5)
            self.assertIn("SCREENSHOT_QUEUE_DONE", output, output)
            files = sorted(path.name for path in directory.glob("screenshot-*.png"))
            self.assertEqual(files, [f"screenshot-{job}.png" for job in saved_jobs], output)
            for name in files:
                self.assertEqual((directory / name).read_bytes(), b"synthetic screenshot")
            events = [json.loads(line) for line in (directory / "capture-events.jsonl").read_text().splitlines()]
            self.assertEqual([event["job"] for event in events if event["event"] == "started"],
                             list(range(1, executed_jobs + 1)))
            for job in range(2, executed_jobs + 1):
                previous_end = next(index for index, event in enumerate(events)
                                    if event["job"] == job - 1 and event["event"] in ("finished", "failed"))
                next_start = events.index({"job": job, "event": "started"})
                self.assertLess(previous_end, next_start)


if __name__ == "__main__":
    unittest.main()
