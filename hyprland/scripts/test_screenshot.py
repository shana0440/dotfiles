import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("screenshot.sh")
BASH = shutil.which("bash")
MOCK_COMMAND = '''
import json
import os
from pathlib import Path
import sys
import time

state = Path(os.environ["MOCK_STATE"])
command = Path(sys.argv[0]).name
if command == "slurp":
    sys.stdin.buffer.read()
    if os.environ.get("SLURP_CANCEL") == "1":
        sys.exit(1)
    print(os.environ.get("SLURP_GEOMETRY", "10,20 300x200"))
elif command == "grim":
    (state / "grim-args.json").write_text(json.dumps(sys.argv[1:]))
    Path(sys.argv[-1]).write_bytes(b"mock PNG")
    if os.environ.get("GRIM_FAIL") == "1":
        sys.exit(1)
elif command == "wl-copy":
    if os.environ.get("CLIPBOARD_FAIL") == "1":
        sys.exit(1)
    (state / "clipboard").write_bytes(sys.stdin.buffer.read())
elif command == "quickshell":
    (state / "notification-args.json").write_text(json.dumps(sys.argv[1:]))
    time.sleep(float(os.environ.get("NOTIFICATION_DELAY", "0")))
    if os.environ.get("NOTIFICATION_FAIL") == "1":
        sys.exit(1)
elif command == "date":
    print("2026-10-31_12-00-00")
'''


class ScreenshotTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / "home"
        self.home.mkdir()
        commands = self.root / "bin"
        commands.mkdir()
        for name in ["grim", "slurp", "wl-copy", "quickshell", "date"]:
            command = commands / name
            command.write_text(f"#!{sys.executable}\n{MOCK_COMMAND}")
            command.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), MOCK_STATE=str(self.root))
        self.env["PATH"] = str(commands) + os.pathsep + os.environ["PATH"]
        self.env.pop("XDG_PICTURES_DIR", None)
        self.env.pop("XDG_CONFIG_HOME", None)
        self.clipboard = self.root / "clipboard"
        self.clipboard.write_bytes(b"original clipboard")
        self.directory = self.home / "Pictures/Screenshots"

    def capture(self, mode, **environment):
        return subprocess.run(
            [BASH, str(SCRIPT), mode],
            env={**self.env, **environment},
            capture_output=True,
            text=True,
            timeout=5,
        )

    def test_full_screen_is_saved_and_copied(self):
        result = self.capture("full")
        self.assertEqual(result.returncode, 0, result.stderr)
        path = Path(result.stdout.strip())
        self.assertEqual(path.parent, self.directory)
        self.assertEqual(path.suffix, ".png")
        self.assertEqual(path.read_bytes(), b"mock PNG")
        self.assertEqual(self.clipboard.read_bytes(), b"mock PNG")
        self.assertEqual(json.loads((self.root / "grim-args.json").read_text()), [str(path)])
        self.assertEqual(
            json.loads((self.root / "notification-args.json").read_text()),
            [
                "--path", str(self.home / ".config/quickshell"),
                "ipc", "call", "screenshots", "captured", str(path),
            ],
        )

    def test_region_geometry_is_one_argument(self):
        result = self.capture("region")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads((self.root / "grim-args.json").read_text()),
            ["-g", "10,20 300x200", result.stdout.strip()],
        )

    def test_region_does_not_wait_for_gui_stdin(self):
        with subprocess.Popen(
            [BASH, str(SCRIPT), "region"], env=self.env,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        ) as process:
            self.assertEqual(process.wait(timeout=3), 0)

    def test_cancel_preserves_clipboard_and_creates_no_files(self):
        result = self.capture("region", SLURP_CANCEL="1")
        self.assertEqual(result.returncode, 0)
        self.assertFalse(self.directory.exists())
        self.assertFalse((self.root / "grim-args.json").exists())
        self.assertFalse((self.root / "notification-args.json").exists())
        self.assertEqual(self.clipboard.read_bytes(), b"original clipboard")

    def test_empty_selection_cancels(self):
        result = self.capture("region", SLURP_GEOMETRY="")
        self.assertEqual(result.returncode, 0)
        self.assertFalse(self.directory.exists())

    def test_failed_capture_removes_partial_file(self):
        result = self.capture("full", GRIM_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(self.directory.iterdir()), [])
        self.assertFalse((self.root / "notification-args.json").exists())
        self.assertEqual(self.clipboard.read_bytes(), b"original clipboard")

    def test_clipboard_failure_preserves_the_screenshot(self):
        result = self.capture("full", CLIPBOARD_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        paths = list(self.directory.glob("*.png"))
        self.assertEqual(len(paths), 1)
        self.assertEqual(paths[0].read_bytes(), b"mock PNG")
        self.assertTrue((self.root / "notification-args.json").exists())

    def test_captures_in_the_same_second_have_unique_names(self):
        first = self.capture("full")
        second = self.capture("full")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertNotEqual(first.stdout, second.stdout)
        self.assertEqual(len(list(self.directory.glob("*.png"))), 2)

    def test_pictures_directory_override(self):
        pictures = self.root / "Custom pictures"
        result = self.capture("full", XDG_PICTURES_DIR=str(pictures))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(result.stdout.strip()).parent, pictures / "Screenshots")

    def test_notification_failure_preserves_capture_and_clipboard(self):
        result = self.capture("full", NOTIFICATION_FAIL="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(result.stdout.strip()).read_bytes(), b"mock PNG")
        self.assertEqual(self.clipboard.read_bytes(), b"mock PNG")

    def test_notification_timeout_preserves_capture_and_clipboard(self):
        result = self.capture("full", NOTIFICATION_DELAY="10")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(result.stdout.strip()).read_bytes(), b"mock PNG")
        self.assertEqual(self.clipboard.read_bytes(), b"mock PNG")

    def test_notification_uses_xdg_config_home(self):
        config = self.root / "Custom config"
        result = self.capture("full", XDG_CONFIG_HOME=str(config))
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = json.loads((self.root / "notification-args.json").read_text())
        self.assertEqual(arguments[1], str(config / "quickshell"))
        self.assertEqual(arguments[-1], result.stdout.strip())

    def test_invalid_mode(self):
        result = self.capture("invalid")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage:", result.stderr)
        self.assertFalse(self.directory.exists())


if __name__ == "__main__":
    unittest.main()
