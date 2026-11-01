"""Exercise the real Quickshell service with isolated, deliberately delayed helpers."""
import os
import selectors
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
MOCK = '''
import json
import os
from pathlib import Path
import sys
import time

state = Path(os.environ["CAPTURE_TEST_STATE"])
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
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            config = directory / "config"
            shutil.copytree(ROOT / "config", config)
            shutil.copy(ROOT / "tests/fixtures/CaptureLifecycle.qml", config / "shell.qml")
            commands = directory / "bin"
            commands.mkdir()
            for name in ("hypr-screenshot", "hypr-record"):
                command = commands / name
                command.write_text(f"#!{sys.executable}\n{MOCK}")
                command.chmod(0o755)
            runtime = directory / "runtime"
            runtime.mkdir(mode=0o700)
            environment = {
                **os.environ,
                "PATH": str(commands) + os.pathsep + os.environ["PATH"],
                "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                "XDG_RUNTIME_DIR": str(runtime), "XDG_CACHE_HOME": str(directory / "cache"),
                "WAYLAND_DISPLAY": "nonexistent-test-display",
                "DBUS_SESSION_BUS_ADDRESS": "unix:path=/nonexistent-test-bus",
                "CAPTURE_TEST_STATE": str(directory),
            }
            process = subprocess.Popen(
                [shutil.which("quickshell"), "--no-color", "--path", str(config)],
                env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, start_new_session=True,
            )
            output = ""
            try:
                with selectors.DefaultSelector() as selector:
                    selector.register(process.stdout, selectors.EVENT_READ)
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
                        generation_output = ""
                        deadline = time.monotonic() + 15
                        while time.monotonic() < deadline:
                            if not selector.select(timeout=0.1):
                                continue
                            data = os.read(process.stdout.fileno(), 65536)
                            if not data:
                                break
                            generation_output += data.decode()
                            if "CAPTURE_TEST_PASS" in generation_output or "CAPTURE_TEST_FAIL" in generation_output:
                                break
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
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                remaining, _ = process.communicate(timeout=5)
                output += remaining
            self.assertIn("CAPTURE_TEST_PASS", output, output)
            self.assertNotIn("CAPTURE_TEST_FAIL", output, output)
            self.assertEqual((directory / "starts").read_text(), "6")
            self.assertEqual((directory / "screenshots").read_text(), "6")


if __name__ == "__main__":
    unittest.main()
