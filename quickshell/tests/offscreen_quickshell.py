"""Run production QML against fake commands, never the desktop or session bus."""
from contextlib import contextmanager
import os
from pathlib import Path
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


@contextmanager
def offscreen_shell(fixture, commands):
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        config = directory / "config"
        shutil.copytree(ROOT / "config", config)
        shutil.copy(ROOT / "tests/fixtures" / fixture, config / "shell.qml")
        binaries = directory / "bin"
        binaries.mkdir()
        for name, script in commands.items():
            command = binaries / name
            command.write_text(f"#!{sys.executable}\n{script}")
            command.chmod(0o755)
        runtime = directory / "runtime"
        runtime.mkdir(mode=0o700)
        environment = {
            **os.environ,
            "PATH": str(binaries) + os.pathsep + os.environ["PATH"],
            "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
            "XDG_RUNTIME_DIR": str(runtime), "XDG_CACHE_HOME": str(directory / "cache"),
            "WAYLAND_DISPLAY": "nonexistent-test-display",
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=/nonexistent-test-bus",
            "QUICKSHELL_TEST_STATE": str(directory),
        }
        process = subprocess.Popen(
            [shutil.which("quickshell"), "--no-color", "--path", str(config)],
            env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, start_new_session=True,
        )
        try:
            yield directory, config, environment, process
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
            process.communicate(timeout=5)


def read_until(process, marker, timeout=15):
    output = ""
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if not selector.select(timeout=0.1):
                continue
            data = os.read(process.stdout.fileno(), 65536)
            if not data:
                break
            output += data.decode()
            if marker in output:
                break
    return output
