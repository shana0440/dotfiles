"""Freeze launch-time desktop/window frames; save screenshots without capture UI."""

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time


def snapshot_path(value):
    path = Path(value).resolve()
    runtime = Path(os.environ["XDG_RUNTIME_DIR"]).resolve()
    if path.parent != runtime or not path.name.startswith("screen-capture-frame-"):
        raise ValueError("Invalid snapshot directory")
    return path


def visible_windows(screens):
    """Freeze geometry/stacking from Hyprland before our layer surfaces appear."""
    try:
        def query(name):
            return json.loads(subprocess.check_output(
                ["hyprctl", "-j", name], timeout=2, stderr=subprocess.DEVNULL))
        monitors = query("monitors")
        workspaces = {monitor["activeWorkspace"]["id"] for monitor in monitors}
        workspaces.update(monitor.get("specialWorkspace", {}).get("id", 0) for monitor in monitors)
        clients = query("clients")
        windows = []
        for client in clients:
            identifier = client.get("stableId", "")
            if (not client.get("mapped") or client.get("hidden") or not client.get("visible", True)
                    or client.get("workspace", {}).get("id") not in workspaces
                    or not re.fullmatch(r"[0-9a-fA-F]+", str(identifier))):
                continue
            x, y = client["at"]
            width, height = client["size"]
            if width <= 0 or height <= 0:
                continue
            def overlap(screen):
                return max(0, min(x + width, screen["x"] + screen["width"]) - max(x, screen["x"])) * max(
                    0, min(y + height, screen["y"] + screen["height"]) - max(y, screen["y"]))
            screen = max(screens, key=overlap)
            if not overlap(screen):
                continue
            windows.append({
                "identifier": str(identifier), "address": client["address"],
                "title": client.get("title") or client.get("class") or "Window",
                "x": x, "y": y, "width": width, "height": height,
                "screenName": screen["name"], "floating": client.get("floating", False),
                "focusOrder": client.get("focusHistoryID", 999),
            })
        # Floating windows cover tiles; recent focus determines overlapping floats.
        windows.sort(key=lambda window: (not window["floating"], window["focusOrder"]))
        error = "" if windows else "No visible windows with native capture identifiers."
        return windows, error
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        return [], "Window capture requires Hyprland with native toplevel capture support."


def freeze_window(directory, window):
    target = directory / f"window-{window['identifier']}.png"
    temporary = target.with_suffix(".tmp")
    try:
        # Native capture excludes occluding windows and our frozen preview surfaces.
        subprocess.run(["grim", "-t", "png", "-l", "0", "-T", window["identifier"], str(temporary)],
                                timeout=5, capture_output=True, check=True)
        temporary.replace(target)
    except (OSError, subprocess.SubprocessError) as error:
        temporary.unlink(missing_ok=True)
        message = "The window closed or native window capture is unavailable."
        if isinstance(error, subprocess.CalledProcessError):
            message += " " + error.stderr.decode(errors="replace").strip()
        target.with_suffix(".error").write_text(message)


def freeze(screens):
    if not screens:
        raise ValueError("No screens available")
    left = min(screen["x"] for screen in screens)
    top = min(screen["y"] for screen in screens)
    width = max(screen["x"] + screen["width"] for screen in screens) - left
    height = max(screen["y"] + screen["height"] for screen in screens) - top
    directory = Path(tempfile.mkdtemp(prefix="screen-capture-frame-", dir=os.environ["XDG_RUNTIME_DIR"]))
    try:
        with ThreadPoolExecutor(max_workers=4) as workers:
            window_list = workers.submit(visible_windows, screens)
            target = directory / "desktop.ppm"
            subprocess.run(["grim", "-t", "ppm", str(target)], check=True, timeout=10)
            with target.open("rb") as stream:
                if stream.readline().strip() != b"P6":
                    raise ValueError("Unexpected compositor image format")
                pixel_width, pixel_height = map(int, stream.readline().split())
                if stream.readline().strip() != b"255":
                    raise ValueError("Unexpected compositor image depth")
            scale_x, scale_y = pixel_width / width, pixel_height / height
            for screen in screens:
                x, y = screen["x"] - left, screen["y"] - top
                clip_x, clip_y = round(x * scale_x), round(y * scale_y)
                screen["image"] = str(target)
                screen["clip"] = {
                    "x": clip_x, "y": clip_y,
                    "width": round((x + screen["width"]) * scale_x) - clip_x,
                    "height": round((y + screen["height"]) * scale_y) - clip_y,
                }
            windows, window_error = window_list.result()
            for window in windows:
                workers.submit(freeze_window, directory, window)
            manifest = {"directory": str(directory), "x": left, "y": top,
                        "width": width, "height": height, "screens": screens,
                        "windows": windows, "windowError": window_error}
            (directory / "manifest.json").write_text(json.dumps(manifest))
            # Show the toolbar now; native window frames finish in parallel, without
            # making full-screen/region users wait for every window to be exported.
            print(json.dumps(manifest), flush=True)
    except BaseException:
        shutil.rmtree(directory, ignore_errors=True)
        raise


def save(directory, geometry="", identifier=None):
    from PIL import Image

    directory = snapshot_path(directory)
    manifest = json.loads((directory / "manifest.json").read_text())
    if identifier is not None:
        if identifier not in {window["identifier"] for window in manifest["windows"]}:
            raise ValueError("The selected window is not part of this frozen frame")
        source_path = directory / f"window-{identifier}.png"
        deadline = time.monotonic() + 6
        while not source_path.exists():
            error_path = source_path.with_suffix(".error")
            if error_path.exists():
                raise ValueError(error_path.read_text())
            if time.monotonic() >= deadline:
                raise ValueError("Timed out waiting for the frozen window image")
            time.sleep(0.02)
    else:
        source_path = directory / "desktop.ppm"
    with Image.open(source_path) as source:
        image = source.copy()
    if geometry:
        match = re.fullmatch(r"(-?\d+),(-?\d+) ([1-9]\d*)x([1-9]\d*)", geometry)
        if not match:
            raise ValueError("Invalid screenshot geometry")
        x, y, width, height = map(int, match.groups())
        x, y = x - manifest["x"], y - manifest["y"]
        if x < 0 or y < 0 or x + width > manifest["width"] or y + height > manifest["height"]:
            raise ValueError("Screenshot region is outside the frozen desktop")
        scale_x, scale_y = image.width / manifest["width"], image.height / manifest["height"]
        image = image.crop((round(x * scale_x), round(y * scale_y),
                            round((x + width) * scale_x), round((y + height) * scale_y)))
    pictures = Path(os.environ.get("XDG_PICTURES_DIR", str(Path.home() / "Pictures"))) / "Screenshots"
    pictures.mkdir(parents=True, exist_ok=True)
    fd, target = tempfile.mkstemp(prefix=f"Screenshot-{datetime.now():%Y-%m-%d_%H-%M-%S}-", suffix=".png", dir=pictures)
    try:
        with os.fdopen(fd, "wb") as stream:
            image.save(stream, format="PNG", compress_level=1)
    except BaseException:
        Path(target).unlink(missing_ok=True)
        raise
    print(target, flush=True)
    try:
        with open(target, "rb") as stream:
            subprocess.run(["wl-copy", "--type", "image/png"], stdin=stream, check=False, timeout=5)
    except subprocess.TimeoutExpired:
        print("Screen capture: clipboard delivery timed out; screenshot was saved", file=sys.stderr)


if __name__ == "__main__":
    try:
        command = sys.argv[1]
        if command == "freeze":
            freeze(json.loads(sys.argv[2]))
        elif command == "save":
            save(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
        elif command == "save-window":
            save(sys.argv[2], identifier=sys.argv[3])
        elif command == "cleanup":
            shutil.rmtree(snapshot_path(sys.argv[2]), ignore_errors=True)
        else:
            raise ValueError("Expected freeze, save, save-window, or cleanup")
    except Exception as error:
        print(f"Screen capture: {error}", file=sys.stderr)
        sys.exit(1)
