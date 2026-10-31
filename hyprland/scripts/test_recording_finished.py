import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("recording_finished.sh")
BASH = shutil.which("bash")
MOCK_COMMAND = '''
import json
import os
from pathlib import Path
import sys

state = Path(os.environ["MOCK_STATE"])
command = Path(sys.argv[0]).name
arguments = sys.argv[1:]
if command == "ffmpeg":
    (state / "ffmpeg.json").write_text(json.dumps(arguments))
    Path(arguments[-1]).write_bytes(b"mock PNG")
    if os.environ.get("THUMBNAIL_FAIL") == "1":
        sys.exit(1)
elif command == "quickshell":
    (state / "notification.json").write_text(json.dumps(arguments))
    if os.environ.get("NOTIFICATION_FAIL") == "1":
        sys.exit(1)
'''


class RecordingFinishedTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.runtime = self.root / "runtime"
        self.runtime.mkdir()
        self.video = self.home / "Recording #1.mp4"
        self.video.write_bytes(b"mock MP4")
        self.session_file = self.runtime / "hypr-record-full.path"
        self.session_file.write_bytes(os.fsencode(self.video) + b"\0")
        commands = self.root / "bin"
        commands.mkdir()
        for name in ["ffmpeg", "quickshell"]:
            command = commands / name
            command.write_text(f"#!{sys.executable}\n{MOCK_COMMAND}")
            command.chmod(0o755)
        self.env = dict(
            os.environ, HOME=str(self.home), MOCK_STATE=str(self.root),
            XDG_RUNTIME_DIR=str(self.runtime), SERVICE_RESULT="success",
        )
        self.env["PATH"] = str(commands) + os.pathsep + os.environ["PATH"]
        self.env.pop("XDG_CACHE_HOME", None)
        self.env.pop("XDG_CONFIG_HOME", None)
        self.thumbnail = self.home / ".cache/quickshell/recordings/Recording #1.mp4.png"

    def finish(self, mode="full", **environment):
        return subprocess.run(
            [BASH, str(SCRIPT), mode], env={**self.env, **environment},
            capture_output=True, text=True, timeout=5,
        )

    def notification(self):
        return json.loads((self.root / "notification.json").read_text())

    def test_success_creates_thumbnail_and_notifies_saved_video_path(self):
        result = self.finish()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.session_file.exists())
        self.assertEqual(self.thumbnail.read_bytes(), b"mock PNG")
        self.assertEqual(
            self.notification(),
            ["--path", str(self.home / ".config/quickshell"), "ipc", "call", "recordings", "saved",
             str(self.video), str(self.thumbnail)],
        )
        arguments = json.loads((self.root / "ffmpeg.json").read_text())
        self.assertEqual(arguments[arguments.index("-i") + 1], str(self.video))
        self.assertEqual(arguments[arguments.index("-frames:v") + 1], "1")
        self.assertIn("-nostdin", arguments)

    def test_region_completion_uses_its_own_session(self):
        region_session = self.runtime / "hypr-record-region.path"
        region_session.write_bytes(os.fsencode(self.video) + b"\0")
        result = self.finish("region")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(region_session.exists())
        self.assertTrue(self.session_file.exists())
        self.assertEqual(self.notification()[-2], str(self.video))

    def test_empty_recording_is_not_reported_as_saved(self):
        self.video.write_bytes(b"")
        result = self.finish()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "notification.json").exists())
        self.assertFalse(self.session_file.exists())

    def test_failed_recording_is_not_reported_as_saved(self):
        result = self.finish(SERVICE_RESULT="exit-code")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "notification.json").exists())
        self.assertTrue(self.video.exists())

    def test_thumbnail_failure_still_notifies_without_preview(self):
        result = self.finish(THUMBNAIL_FAIL="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.thumbnail.exists())
        self.assertEqual(self.notification()[-2:], [str(self.video), ""])

    def test_missing_shell_keeps_the_recording(self):
        result = self.finish(NOTIFICATION_FAIL="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.video.read_bytes(), b"mock MP4")

    def test_completion_is_not_notified_twice(self):
        result = self.finish()
        self.assertEqual(result.returncode, 0, result.stderr)
        (self.root / "notification.json").unlink()
        result = self.finish()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "notification.json").exists())

    def test_xdg_directories_are_respected(self):
        cache = self.root / "Custom cache"
        config = self.root / "Custom config"
        result = self.finish(XDG_CACHE_HOME=str(cache), XDG_CONFIG_HOME=str(config))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.notification()[1], str(config / "quickshell"))
        self.assertEqual(self.notification()[-1], str(cache / "quickshell/recordings/Recording #1.mp4.png"))

    def test_invalid_mode_preserves_session(self):
        result = self.finish("invalid")
        self.assertEqual(result.returncode, 2)
        self.assertTrue(self.session_file.exists())


if __name__ == "__main__":
    unittest.main()
