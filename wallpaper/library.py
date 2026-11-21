import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
VIDEO_EXTENSIONS = {".mp4", ".webm", ".mkv", ".mov"}
EXTENSIONS = IMAGE_EXTENSIONS | VIDEO_EXTENSIONS


def is_video(path):
    return path.suffix.lower() in VIDEO_EXTENSIONS


def cached_name(source, extension):
    stat = source.stat()
    key = hashlib.sha256(str(source).encode()).hexdigest()
    return f"{key}-{stat.st_mtime_ns}-{stat.st_size}{extension}"


def poster(video):
    posters = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "wallpaper/posters"
    posters.mkdir(parents=True, exist_ok=True)
    target = posters / cached_name(video, ".png")
    if not target.is_file():
        fd, temp = tempfile.mkstemp(suffix=".png", dir=posters)
        os.close(fd)
        try:
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(video), "-frames:v", "1", temp],
                           check=True, capture_output=True, timeout=30)
            os.replace(temp, target)
        finally:
            Path(temp).unlink(missing_ok=True)
    return target


def still(source):
    return poster(source) if is_video(source) else source


def thumbnail_cache():
    return Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "wallpaper/thumbnails"


def thumbnail_path(source, cache):
    return cache / cached_name(source, ".jpg")


def thumbnail(source, cache):
    target = thumbnail_path(source, cache)
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
                      if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS),
                     key=lambda p: p.name.casefold())
    cache.mkdir(parents=True, exist_ok=True)
    items, errors = [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        jobs = [(p, pool.submit(thumbnail, p, cache)) for p in sources]
        for source, job in jobs:
            try:
                items.append(job.result())
            except (OSError, subprocess.SubprocessError) as error:
                errors.append(f"{source.name}: {error}")
    live = {Path(item["thumbnail"].split("/")[-1]).name for item in items}
    for old in cache.glob("*.jpg"):
        if old.name not in live and is_hash_named_thumbnail(old):
            old.unlink(missing_ok=True)
    return {"items": items, "directory": str(directory), "errors": errors}


def is_hash_named_thumbnail(path):
    return len(path.stem.split("-")[0]) == 64


def ipc_environment_without_quickshell_crash_relaunch():
    return {k: v for k, v in os.environ.items() if not k.startswith("__QUICKSHELL_CRASH_")}


def transition_ipc(action, *arguments):
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    shell = os.environ.get("WALLPAPER_SHELL", str(config_home / "quickshell"))
    result = subprocess.run(["quickshell", "--path", shell, "ipc", "call",
                             "wallpaperTransition", action, *arguments],
                            check=True, capture_output=True, text=True, timeout=1,
                            env=ipc_environment_without_quickshell_crash_relaunch())
    return result.stdout.strip()


def wait_transition(token, expected, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        state = json.loads(transition_ipc("status", token))
        if state["phase"] in expected:
            return
        if state["phase"] in {"error", "superseded", "idle"}:
            raise RuntimeError(state.get("error") or "Transition stopped")
        time.sleep(0.01)
    raise TimeoutError("Colony transition timed out")


def colonies(*arguments):
    return subprocess.run(["wallpaper-colonies", *arguments], check=True,
                          capture_output=True, text=True, timeout=10).stdout.strip()


def colony_transition(source, image, covered):
    token = None
    complete = False
    try:
        result = subprocess.run(["awww", "query", "--json"], check=True,
                                capture_output=True, text=True, timeout=2)
        outputs = json.loads(result.stdout).get("", [])
        if not outputs:
            return False
        colony_map = colonies("take")
        cached_thumbnail = thumbnail_path(source, thumbnail_cache())
        color_source = cached_thumbnail if cached_thumbnail.is_file() else image
        request = {"image": str(image), "map": colony_map, "ember": colonies("accent", str(color_source)),
                   "outputs": outputs}
        token = transition_ipc("prepare", json.dumps(request))
        already_heading_there = token == "same"
        if already_heading_there:
            token = None
            complete = True
            print("transition-ready", flush=True)
            return True
        if not token.isdigit():
            token = None
            return False
        wait_transition(token, {"ready"}, 3)
        print("transition-ready", flush=True)
        if transition_ipc("go", token) != "ok":
            raise RuntimeError("Colony transition did not start")
        wait_transition(token, {"swapped"}, 8)
        covered()
        if transition_ipc("release", token) != "ok":
            raise RuntimeError("Colony transition was not held over the screen")
        wait_transition(token, {"done"}, 8)
        complete = True
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


def video_pid_file():
    return Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "wallpaper-video.pid"


def playing_video():
    try:
        pid, video = video_pid_file().read_text().splitlines()[:2]
        os.kill(int(pid), 0)
        return int(pid), Path(video)
    except (OSError, ValueError):
        return None, None


def stop_video():
    pid, _ = playing_video()
    video_pid_file().unlink(missing_ok=True)
    if pid is None:
        return
    os.kill(pid, signal.SIGTERM)
    deadline = time.monotonic() + 1
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except OSError:
            return
        time.sleep(0.01)
    os.kill(pid, signal.SIGKILL)


def play_video(video):
    process = subprocess.Popen(["mpvpaper", "--auto-pause",
                                "--mpv-options", "no-audio loop hwdec=auto panscan=1.0", "ALL", str(video)],
                               stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL, start_new_session=True)
    video_pid_file().write_text(f"{process.pid}\n{video}\n")


def set_wallpaper(source):
    if playing_video()[1] == source:
        return
    image = still(source)
    if not colony_transition(source, image, stop_video):
        stop_video()
        subprocess.run(["awww", "img", str(image), "--transition-type", "fade",
                        "--transition-duration", "0.35"], check=True, timeout=5)
    if is_video(source):
        play_video(source)


def awww_shows_a_wallpaper():
    try:
        result = subprocess.run(["awww", "query", "--json"], check=True,
                                capture_output=True, text=True, timeout=2)
        return any(o.get("displaying", {}).get("image") for o in json.loads(result.stdout).get("", []))
    except (OSError, ValueError, subprocess.SubprocessError):
        return False


def restore_video():
    if not current_file().is_file():
        return
    source = Path(current_file().read_text().splitlines()[0])
    if not is_video(source) or not source.is_file() or playing_video()[1] == source:
        return
    deadline = time.monotonic() + 10
    while not awww_shows_a_wallpaper() and time.monotonic() < deadline:
        time.sleep(0.1)
    stop_video()
    play_video(source)


def video_command(arguments):
    if arguments == ["restore"]:
        restore_video()
    elif arguments == ["state"]:
        print(json.dumps({"playing": str(playing_video()[1] or "")}))
    else:
        raise ValueError("Usage: wallpaper-video restore|state")


def current_file():
    return Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "wallpaper/current"


def record_current(image):
    current_file().parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(dir=current_file().parent)
    try:
        with os.fdopen(fd, "w") as file:
            file.write(f"{image}\n")
        os.replace(temp, current_file())
    finally:
        Path(temp).unlink(missing_ok=True)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "video":
        video_command(sys.argv[2:])
        return
    if len(sys.argv) > 1 and sys.argv[1] == "set":
        if len(sys.argv) != 3:
            raise ValueError("Usage: wallpaper-set IMAGE_OR_VIDEO")
        image = Path(sys.argv[2]).expanduser().resolve(strict=True)
        if not image.is_file() or image.suffix.lower() not in EXTENSIONS:
            raise ValueError("Choose a JPG, PNG, or WebP image, or an MP4, WebM, MKV, or MOV video")
        set_wallpaper(image)
        record_current(image)
        return
    directory = Path(os.environ["WALLPAPER_DIR"]).expanduser().resolve()
    cache = thumbnail_cache()
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
