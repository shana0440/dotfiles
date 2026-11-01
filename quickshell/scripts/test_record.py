import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("record.sh")
BASH = shutil.which("bash")
MOCK_COMMAND = '''
import json
import os
from pathlib import Path
import sys

state = Path(os.environ["MOCK_STATE"])
command = Path(sys.argv[0]).name
arguments = sys.argv[1:]
if command == "systemctl":
    if "is-active" in arguments:
        if "QUERY_FAIL" in os.environ:
            print("Failed to connect to user service manager", file=sys.stderr)
            sys.exit(int(os.environ["QUERY_FAIL"]))
        mode = os.environ.get("ACTIVE_MODE", "none")
        unit_state = os.environ.get("UNIT_STATE", "active")
        print(unit_state if mode == "full" else "inactive")
        print(unit_state if mode == "region" else "inactive")
        sys.exit(0 if mode != "none" and unit_state == "active" else 3)
    (state / "stop.json").write_text(json.dumps(arguments))
elif command == "systemd-run":
    (state / "start.json").write_text(json.dumps(arguments))
    if os.environ.get("START_FAIL") == "1":
        sys.exit(1)
    Path(arguments[-1]).write_bytes(b"mock MP4")
elif command == "slurp":
    sys.stdin.buffer.read()
    if os.environ.get("SLURP_CANCEL") == "1":
        sys.exit(1)
    print(os.environ.get("SLURP_GEOMETRY", "10,20 300x200"))
elif command == "quickshell":
    (state / "selector.json").write_text(json.dumps(arguments))
    sys.exit(0 if os.environ.get("SELECTOR_AVAILABLE") == "1" else 1)
elif command in ["wf-recorder", "hypr-recording-finished"]:
    sys.exit("Recording and completion hooks must be launched by systemd.")
'''


class RecordingTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.runtime = self.root / "runtime"
        self.runtime.mkdir()
        self.commands = self.root / "bin"
        self.commands.mkdir()
        for name in ["systemctl", "systemd-run", "slurp", "wf-recorder", "hypr-recording-finished", "quickshell"]:
            command = self.commands / name
            command.write_text(f"#!{sys.executable}\n{MOCK_COMMAND}")
            command.chmod(0o755)
        self.env = dict(
            os.environ, HOME=str(self.home), MOCK_STATE=str(self.root),
            XDG_RUNTIME_DIR=str(self.runtime), WAYLAND_DISPLAY="wayland-test",
        )
        self.env["PATH"] = str(self.commands) + os.pathsep + os.environ["PATH"]
        self.env.pop("XDG_VIDEOS_DIR", None)
        self.directory = self.home / "Videos/Recordings"

    def run_command(self, *arguments, **environment):
        return subprocess.run(
            [BASH, str(SCRIPT), *arguments],
            env={**self.env, **environment},
            capture_output=True, text=True, timeout=5,
        )

    def start_arguments(self):
        return json.loads((self.root / "start.json").read_text())

    def test_full_recording_uses_requested_monitor_and_graceful_stop(self):
        result = self.run_command("full", "HDMI-A-2")
        self.assertEqual(result.returncode, 0, result.stderr)
        path = Path(result.stdout.strip())
        self.assertEqual(path.parent, self.directory)
        self.assertEqual(path.suffix, ".mp4")
        self.assertEqual(path.read_bytes(), b"mock MP4")
        arguments = self.start_arguments()
        self.assertIn("--unit=hypr-record-full.service", arguments)
        self.assertIn("--property=KillSignal=SIGINT", arguments)
        self.assertIn("--collect", arguments)
        self.assertIn("--setenv=WAYLAND_DISPLAY=wayland-test", arguments)
        self.assertIn(
            f"--property=ExecStopPost={self.commands / 'hypr-recording-finished'} full",
            arguments,
        )
        self.assertEqual(
            (self.runtime / "hypr-record-full.path").read_bytes(), os.fsencode(path) + b"\0\0",
        )
        self.assertEqual(
            arguments[arguments.index("--") + 1:],
            [
                str(self.commands / "wf-recorder"), "--overwrite",
                "--audio-backend=pulse", "--audio=@DEFAULT_MONITOR@", "--audio-codec=aac",
                "-o", "HDMI-A-2", "-f", str(path),
            ],
        )

    def test_both_modes_capture_playback_audio(self):
        for command in [("full", "HDMI-A-2"), ("region",)]:
            with self.subTest(mode=command[0]):
                result = self.run_command(*command)
                self.assertEqual(result.returncode, 0, result.stderr)
                arguments = self.start_arguments()
                self.assertIn("--audio-backend=pulse", arguments)
                self.assertIn("--audio=@DEFAULT_MONITOR@", arguments)
                self.assertIn("--audio-codec=aac", arguments)

    def test_region_prefers_quickshell_selector(self):
        result = self.run_command("region", SELECTOR_AVAILABLE="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.directory.exists())
        self.assertFalse((self.root / "start.json").exists())
        arguments = json.loads((self.root / "selector.json").read_text())
        self.assertEqual(arguments[-4:], ["call", "capture", "selectRegion", "recording"])

    def test_supplied_region_is_persisted_for_overlay(self):
        geometry = "-100,20 300x200"
        result = self.run_command("region", "DP-1", geometry)
        self.assertEqual(result.returncode, 0, result.stderr)
        path = Path(result.stdout.strip())
        self.assertEqual((self.runtime / "hypr-record-region.path").read_bytes(),
                         os.fsencode(path) + b"\0" + geometry.encode() + b"\0")
        self.assertFalse((self.root / "selector.json").exists())
        status = self.run_command("status", "--json", ACTIVE_MODE="region")
        self.assertEqual(json.loads(status.stdout)["geometry"], geometry)

    def test_invalid_region_is_rejected(self):
        result = self.run_command("region", "DP-1", "invalid")
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.directory.exists())

    def test_region_geometry_remains_one_argument(self):
        result = self.run_command("region")
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = self.start_arguments()
        self.assertIn("--unit=hypr-record-region.service", arguments)
        self.assertEqual(arguments[arguments.index("-g") + 1], "10,20 300x200")
        self.assertNotIn("-o", arguments)

    def test_region_does_not_wait_for_gui_stdin(self):
        with subprocess.Popen(
            [BASH, str(SCRIPT), "region"], env=self.env,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        ) as process:
            self.assertEqual(process.wait(timeout=3), 0)

    def test_cancel_creates_no_recording_or_service(self):
        result = self.run_command("region", SLURP_CANCEL="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.directory.exists())
        self.assertFalse((self.root / "start.json").exists())

    def test_empty_selection_cancels(self):
        result = self.run_command("region", SLURP_GEOMETRY="")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "start.json").exists())

    def test_existing_recording_is_preserved(self):
        result = self.run_command("full", "HDMI-A-2", ACTIVE_MODE="region")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "start.json").exists())
        self.assertFalse(self.directory.exists())

    def test_start_waits_for_service_startup_and_completion(self):
        for unit_state in ["activating", "deactivating"]:
            with self.subTest(state=unit_state):
                result = self.run_command("full", "HDMI-A-2", ACTIVE_MODE="region", UNIT_STATE=unit_state)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.root / "start.json").exists())

    def test_concurrent_start_is_rejected(self):
        with (self.runtime / "hypr-record.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_command("full", "HDMI-A-2")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "start.json").exists())

    def test_failed_service_start_removes_empty_file(self):
        result = self.run_command("full", "HDMI-A-2", START_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(self.directory.iterdir()), [])
        self.assertFalse((self.runtime / "hypr-record-full.path").exists())

    def test_stop_targets_only_the_active_recording(self):
        result = self.run_command("stop", ACTIVE_MODE="region")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads((self.root / "stop.json").read_text()),
            ["--user", "stop", "hypr-record-region.service"],
        )

    def test_stop_without_recording_does_nothing(self):
        result = self.run_command("stop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "stop.json").exists())

    def test_recording_query_failures_propagate_without_side_effects(self):
        for code in [1, 4]:
            for arguments in [("status",), ("status", "--json"), ("stop",),
                              ("full", "HDMI-A-2"), ("region",)]:
                with self.subTest(code=code, arguments=arguments):
                    result = self.run_command(*arguments, QUERY_FAIL=str(code))
                    self.assertEqual(result.returncode, code)
                    self.assertEqual(result.stdout, "")
                    self.assertIn("Failed to connect to user service manager", result.stderr)
                    self.assertFalse((self.root / "stop.json").exists())
                    self.assertFalse((self.root / "start.json").exists())
                    self.assertFalse((self.root / "selector.json").exists())
                    self.assertFalse(self.directory.exists())

    def test_inactive_unit_states_are_not_query_failures(self):
        for state in ["inactive", "failed", "unknown"]:
            for arguments in [("status",), ("status", "--json"), ("stop",)]:
                with self.subTest(state=state, arguments=arguments):
                    result = self.run_command(*arguments, ACTIVE_MODE="full", UNIT_STATE=state)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    if arguments == ("status",):
                        self.assertEqual(result.stdout, "none\n")
                    elif arguments == ("status", "--json"):
                        self.assertEqual(json.loads(result.stdout)["mode"], "none")
                    self.assertFalse((self.root / "stop.json").exists())

    def test_status_reports_active_mode(self):
        for mode in ["none", "full", "region"]:
            with self.subTest(mode=mode):
                result = self.run_command("status", ACTIVE_MODE=mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), mode)

    def test_json_status_reports_persisted_start_time(self):
        started_at = 1760000000
        for mode in ["full", "region"]:
            with self.subTest(mode=mode):
                session = self.runtime / f"hypr-record-{mode}.path"
                session.write_bytes(b"video.mp4\0")
                os.utime(session, (started_at, started_at))
                result = self.run_command("status", "--json", ACTIVE_MODE=mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), {"mode": mode, "startedAtSeconds": started_at, "geometry": ""})

    def test_json_status_handles_missing_session_while_finishing(self):
        result = self.run_command("status", "--json", ACTIVE_MODE="full", UNIT_STATE="deactivating")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"mode": "full", "startedAtSeconds": 0, "geometry": ""})

    def test_json_status_without_recording_has_no_start_time(self):
        result = self.run_command("status", "--json")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"mode": "none", "startedAtSeconds": 0, "geometry": ""})

    def test_full_recording_requires_monitor(self):
        result = self.run_command("full")
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.root / "start.json").exists())

    def test_video_directory_override(self):
        videos = self.root / "Custom videos"
        result = self.run_command("full", "HDMI-A-2", XDG_VIDEOS_DIR=str(videos))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(result.stdout.strip()).parent, videos / "Recordings")

    def test_missing_wayland_session_creates_no_recording(self):
        result = self.run_command("full", "HDMI-A-2", WAYLAND_DISPLAY="")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.directory.exists())
        self.assertFalse((self.root / "start.json").exists())

    def test_invalid_mode(self):
        result = self.run_command("invalid")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage:", result.stderr)


if __name__ == "__main__":
    unittest.main()
