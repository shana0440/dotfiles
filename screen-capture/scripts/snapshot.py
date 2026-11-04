"""Freeze the desktop before showing capture UI; save screenshots from that frame."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime


def snapshot_path(value):
    path = Path(value).resolve()
    runtime = Path(os.environ["XDG_RUNTIME_DIR"]).resolve()
    if path.parent != runtime or not path.name.startswith("screen-capture-frame-"):
        raise ValueError("Invalid snapshot directory")
    return path


def freeze(screens):
    if not screens:
        raise ValueError("No screens available")
    left = min(screen["x"] for screen in screens)
    top = min(screen["y"] for screen in screens)
    width = max(screen["x"] + screen["width"] for screen in screens) - left
    height = max(screen["y"] + screen["height"] for screen in screens) - top
    directory = Path(tempfile.mkdtemp(prefix="screen-capture-frame-", dir=os.environ["XDG_RUNTIME_DIR"]))
    try:
        # A raw frame avoids PNG compression, decoding, and per-output re-encoding
        # on the launch path. Qt clips each output directly from this shared image.
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
        manifest = {"directory": str(directory), "x": left, "y": top,
                    "width": width, "height": height, "screens": screens}
        (directory / "manifest.json").write_text(json.dumps(manifest))
        print(json.dumps(manifest), flush=True)
    except BaseException:
        shutil.rmtree(directory)
        raise


def save(directory, geometry):
    # Import and encode only when the user actually saves a screenshot.
    from PIL import Image

    directory = snapshot_path(directory)
    manifest = json.loads((directory / "manifest.json").read_text())
    with Image.open(directory / "desktop.ppm") as source:
        image = source.copy()
    if geometry:
        match = re.fullmatch(r"(-?\d+),(-?\d+) ([1-9]\d*)x([1-9]\d*)", geometry)
        if not match:
            raise ValueError("Invalid screenshot geometry")
        x, y, width, height = map(int, match.groups())
        x, y = x - manifest["x"], y - manifest["y"]
        if x < 0 or y < 0 or x + width > manifest["width"] or y + height > manifest["height"]:
            raise ValueError("Screenshot region is outside the frozen desktop")
        scale_x = image.width / manifest["width"]
        scale_y = image.height / manifest["height"]
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
    # A clipboard failure must not discard a successfully saved screenshot.
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
        elif command == "cleanup":
            shutil.rmtree(snapshot_path(sys.argv[2]), ignore_errors=True)
        else:
            raise ValueError("Expected freeze, save, or cleanup")
    except Exception as error:
        print(f"Screen capture: {error}", file=sys.stderr)
        sys.exit(1)
