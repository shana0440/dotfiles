"""Launch a dedicated OBS setup with paired VDO.Ninja push/view links."""
import fcntl
import json
import os
from pathlib import Path
import secrets
import signal
import subprocess
import sys
import uuid


def main():
    if len(sys.argv) != 1:
        sys.exit("Usage: iphone-webcam")
    os.umask(0o077)
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    root = config_home / "iphone-webcam"
    root.mkdir(parents=True, exist_ok=True)
    # Keep this lock for the whole meeting, including OBS shutdown.
    with (root / "launcher.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            sys.exit("iPhone Webcam is already running. Use its terminal to stop it.")
        credentials = root / "stream.json"
        if not credentials.exists():
            credentials.write_text(json.dumps({
                "id": secrets.token_hex(16),
                "password": secrets.token_hex(16),
            }))
        stream = json.loads(credentials.read_text())
        params = f"{stream['id']}&password={stream['password']}"
        push_url = f"https://vdo.ninja/?push={params}"
        view_url = f"https://vdo.ninja/?view={params}&cleanoutput"
        print("Scan with your iPhone Camera app, open in Safari, and tap Start.", flush=True)
        subprocess.run(["qrencode", "-t", "ANSIUTF8", "-m", "4", push_url], check=True)
        print("Keep this QR private. In OBS, click Start Virtual Camera.", flush=True)

        obs_home = root / "obs-config"
        obs_dir = obs_home / "obs-studio"
        scenes = obs_dir / "basic" / "scenes"
        scenes.mkdir(parents=True, exist_ok=True)
        scene_file = scenes / "iPhone_Webcam.json"
        if not scene_file.exists():
            browser_uuid = str(uuid.uuid4())
            scene_file.write_text(json.dumps({
                "name": "iPhone Webcam",
                "current_scene": "iPhone Webcam",
                "current_program_scene": "iPhone Webcam",
                "scene_order": [{"name": "iPhone Webcam"}],
                "sources": [
                    {
                        "name": "iPhone Camera", "uuid": browser_uuid,
                        "id": "browser_source", "versioned_id": "browser_source",
                        "settings": {"url": view_url, "width": 1920, "height": 1080},
                        "muted": True,
                    },
                    {
                        "name": "iPhone Webcam", "id": "scene", "versioned_id": "scene",
                        "uuid": str(uuid.uuid4()),
                        "settings": {"id_counter": 1, "items": [{
                            "name": "iPhone Camera", "source_uuid": browser_uuid,
                            "id": 1, "visible": True,
                            "pos": {"x": 0.0, "y": 0.0},
                            "scale": {"x": 1.0, "y": 1.0}, "rot": 0.0,
                            "align": 5, "bounds_type": 0,
                        }]},
                    },
                ],
            }, indent=2))
            # These files belong only to the launcher's dedicated OBS setup.
            (obs_dir / "global.ini").write_text(
                "[General]\nFirstRun=false\n\n[Basic]\nProfile=iPhone Webcam\n"
                "ProfileDir=iPhone_Webcam\nSceneCollection=iPhone Webcam\n"
                "SceneCollectionFile=iPhone_Webcam\n"
            )
            (obs_dir / "user.ini").write_text(
                "[General]\nFirstRun=true\n\n[Basic]\n"
                "Profile=iPhone Webcam\nProfileDir=iPhone_Webcam\n"
                "SceneCollection=iPhone Webcam\nSceneCollectionFile=iPhone_Webcam\n"
                "ConfigOnNewProfile=false\n"
            )
            profile = obs_dir / "basic" / "profiles" / "iPhone_Webcam"
            profile.mkdir(parents=True, exist_ok=True)
            (profile / "basic.ini").write_text(
                "[General]\nName=iPhone Webcam\n\n[Video]\n"
                "BaseCX=1920\nBaseCY=1080\nOutputCX=1920\nOutputCY=1080\n"
                "FPSType=0\nFPSCommon=30\n"
            )

        env = dict(os.environ, XDG_CONFIG_HOME=str(obs_home))
        log_dir = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "iphone-webcam"
        log_dir.mkdir(parents=True, exist_ok=True)

        def stop(signum, frame):
            raise KeyboardInterrupt

        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            signal.signal(sig, stop)
        obs = None
        with (log_dir / "obs.log").open("a") as log:
            try:
                # OBS has its own session; this supervisor owns its lifetime.
                obs = subprocess.Popen([
                    "obs", "--multi", "--disable-shutdown-check",
                    "--collection", "iPhone Webcam", "--profile", "iPhone Webcam",
                    "--scene", "iPhone Webcam",
                ], env=env, stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                    start_new_session=True)
                print("OBS is running. Press Ctrl+C to end the meeting and close OBS.", flush=True)
                result = obs.wait()
                if result:
                    print(f"OBS exited with status {result}. See {log_dir / 'obs.log'}.", file=sys.stderr)
            except KeyboardInterrupt:
                print("\nStopping OBS…", flush=True)
            finally:
                for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
                    signal.signal(sig, signal.SIG_IGN)
                if obs is not None:
                    if obs.poll() is None:
                        try:
                            os.killpg(obs.pid, signal.SIGINT)
                        except ProcessLookupError:
                            pass
                        try:
                            obs.wait(timeout=10)
                        except subprocess.TimeoutExpired:
                            try:
                                os.killpg(obs.pid, signal.SIGKILL)
                            except ProcessLookupError:
                                pass
                            obs.wait()
                    # Clean up any browser helpers left in OBS's private group.
                    try:
                        os.killpg(obs.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                print("iPhone Webcam stopped.", flush=True)


if __name__ == "__main__":
    main()
