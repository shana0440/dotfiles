"""Wallpaper picker backend; external tools are provided by wallpaper.nix."""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def thumbnail(source, cache):
    stat = source.stat()
    key = hashlib.sha256(str(source).encode()).hexdigest()
    target = cache / f"{key}-{stat.st_mtime_ns}-{stat.st_size}.jpg"
    if not target.is_file():
        fd, temp = tempfile.mkstemp(suffix=".jpg", dir=cache)
        os.close(fd)
        try:
            subprocess.run([
                "magick", f"{source}[0]", "-auto-orient", "-thumbnail", "900x500>",
                "-strip", "-quality", "85", temp,
            ], check=True, capture_output=True, timeout=30)
            os.replace(temp, target)
        finally:
            Path(temp).unlink(missing_ok=True)
    return {"name": source.name, "path": str(source), "thumbnail": target.as_uri()}


def catalog(directory, cache):
    if not directory.exists():
        return {"items": [], "directory": str(directory), "errors": []}
    sources = sorted((p for p in directory.iterdir()
                      if p.is_file() and p.suffix.lower() in EXTENSIONS),
                     key=lambda p: p.name.casefold())
    cache.mkdir(parents=True, exist_ok=True)
    items, errors = [], []
    # Bound both decoder concurrency and individual conversion time.
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        jobs = [(p, pool.submit(thumbnail, p, cache)) for p in sources]
        for source, job in jobs:
            try:
                items.append(job.result())
            except (OSError, subprocess.SubprocessError) as error:
                errors.append(f"{source.name}: {error}")
    # Only our hash-named thumbnails live in this dedicated cache.
    live = {Path(item["thumbnail"].split("/")[-1]).name for item in items}
    for old in cache.glob("*.jpg"):
        if old.name not in live and len(old.stem.split("-")[0]) == 64:
            old.unlink(missing_ok=True)
    return {"items": items, "directory": str(directory), "errors": errors}


def ipc_environment():
    # A Quickshell restarted after a crash exports __QUICKSHELL_CRASH_* to its
    # children (e.g. the picker running wallpaper-set). An IPC client that
    # inherits them treats itself as the crash relaunch and aborts.
    return {k: v for k, v in os.environ.items() if not k.startswith("__QUICKSHELL_CRASH_")}


def transition_ipc(action, *arguments):
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    shell = os.environ.get("WALLPAPER_SHELL", str(config_home / "quickshell"))
    result = subprocess.run(["quickshell", "--path", shell, "ipc", "call",
                             "wallpaperTransition", action, *arguments],
                            check=True, capture_output=True, text=True, timeout=1,
                            env=ipc_environment())
    return result.stdout.strip()


def wait_transition(token, expected, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        state = json.loads(transition_ipc("status", token))
        if state["phase"] == expected:
            return
        if state["phase"] in {"error", "superseded", "idle"}:
            raise RuntimeError(state.get("error") or "Transition stopped")
        time.sleep(0.03)
    raise TimeoutError("Colony transition timed out")


def colonies(*arguments):
    return subprocess.run(["wallpaper-colonies", *arguments], check=True,
                          capture_output=True, text=True, timeout=10).stdout.strip()


def colony_transition(image):
    """Run the Quickshell colony transition; False means "use a fade instead"."""
    token = None
    complete = False
    try:
        result = subprocess.run(["awww", "query", "--json"], check=True,
                                capture_output=True, text=True, timeout=2)
        outputs = json.loads(result.stdout).get("", [])
        if not outputs:
            return False
        colony_map = colonies("take")
        request = {"image": str(image), "map": colony_map, "ember": colonies("accent", str(image)),
                   "outputs": outputs}
        token = transition_ipc("prepare", json.dumps(request))
        if token == "same":
            # Already shown, or the newest running change already heads there.
            token = None
            complete = True
            print("transition-ready", flush=True)
            return True
        if not token.isdigit():
            token = None
            return False
        wait_transition(token, "ready", 3)
        # The picker closes before the effect starts. A successful exit still
        # means the whole hand-over to awww has finished.
        print("transition-ready", flush=True)
        time.sleep(0.15)
        if transition_ipc("go", token) != "ok":
            raise RuntimeError("Colony transition did not start")
        wait_transition(token, "done", 8)
        complete = True
        # Replace the used map in the background so patterns never repeat.
        subprocess.Popen(["wallpaper-colonies", "renew", colony_map], stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return True
    except (OSError, ValueError, KeyError, RuntimeError, TimeoutError, subprocess.SubprocessError) as error:
        print(f"Colony transition unavailable; using fade: {error}", file=sys.stderr)
        return False
    finally:
        if token and not complete:
            try:
                transition_ipc("abort", token)
            except (OSError, subprocess.SubprocessError):
                pass


def set_wallpaper(image):
    # Changes may overlap: Quickshell stacks each transition above the ones
    # still running and switches awww in order as each one completes.
    if not colony_transition(image):
        subprocess.run(["awww", "img", str(image), "--transition-type", "fade",
                        "--transition-duration", "0.35"], check=True, timeout=5)


def publish_login(image):
    # The login screen runs before the session, as another user that cannot
    # read ~, so it shows a copy kept at LOGIN_WALLPAPER. Hosts without that
    # folder (nixos/login.nix creates it) have no such login screen.
    target = os.environ.get("LOGIN_WALLPAPER")
    if not target or not Path(target).parent.is_dir():
        return
    target = Path(target)
    fd, temp = tempfile.mkstemp(suffix=".jpg", dir=target.parent)
    os.close(fd)
    try:
        subprocess.run([
            "magick", f"{image}[0]", "-auto-orient", "-resize", "2560x1440^",
            "-strip", "-quality", "90", temp,
        ], check=True, capture_output=True, timeout=60)
        os.chmod(temp, 0o644)
        os.replace(temp, target)
    finally:
        Path(temp).unlink(missing_ok=True)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "set":
        if len(sys.argv) != 3:
            raise ValueError("Usage: wallpaper-set IMAGE")
        image = Path(sys.argv[2]).expanduser().resolve(strict=True)
        if not image.is_file() or image.suffix.lower() not in EXTENSIONS:
            raise ValueError("Choose a JPG, PNG, or WebP image")
        set_wallpaper(image)
        try:
            publish_login(image)
        except (OSError, subprocess.SubprocessError) as error:
            # The desktop changed; a stale login wallpaper is not worth failing over.
            print(f"Login wallpaper not updated: {error}", file=sys.stderr)
        return
    directory = Path(os.environ["WALLPAPER_DIR"]).expanduser().resolve()
    cache = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "wallpaper/thumbnails"
    # A single refresh at a time prevents another refresh's cleanup from
    # deleting a thumbnail that is still being generated.
    import fcntl
    cache.mkdir(parents=True, exist_ok=True)
    with (cache.parent / "refresh.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        print(json.dumps(catalog(directory, cache)))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
