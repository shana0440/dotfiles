"""Regression coverage for helper startup and decoding failures."""
import shutil
import subprocess
import time
import unittest

from offscreen_quickshell import offscreen_shell, read_until


@unittest.skipUnless(shutil.which("quickshell"), "requires Quickshell")
class ServiceFailureTests(unittest.TestCase):
    def test_failed_start_can_retry_and_decoding_errors_surface(self):
        commands = {
            "hypr-record": 'import sys\nprint(\'{"mode":"none"}\')\n',
            "pipewire-playback-monitor": 'import time\ntime.sleep(0.5)\nprint("{invalid", flush=True)\ntime.sleep(30)\n',
        }
        with offscreen_shell("ServiceFailures.qml", commands) as (directory, config, env, process):
            output = read_until(process, "FAILURE_TEST_READY")
            self.assertIn("FAILURE_TEST_READY", output)

            def call(method):
                return subprocess.check_output(
                    [shutil.which("quickshell"), "--path", str(config), "ipc", "call", "failureTest", method],
                    env=env, text=True, timeout=3,
                ).strip()

            self.assertEqual(call("malformedStatus"), "SyntaxError")
            # Keep the command in PATH but make exec fail, regardless of host helpers.
            helper = directory / "bin/hypr-record"
            helper.write_text("#!/nonexistent-test-interpreter\n")
            for _ in range(2):
                call("startRegion")
                self.assertEqual(call("pending"), "true")
                deadline = time.monotonic() + 3
                while call("pending") == "true" and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertEqual(call("pending"), "false", "failed startup left the outline pending")
            output += read_until(process, "SyntaxError", timeout=3)
            self.assertIn("SyntaxError", output, "malformed playback event did not surface")


if __name__ == "__main__":
    unittest.main()
