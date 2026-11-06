"""Generate owned desktop entries for AppImages without running their application code."""

import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


PREFIX = "managed-appimage-"


def desktop_value(value):
    return value.replace("\\", "\\\\").replace("\n", "\\n").replace("\r", "")


def exec_arg(value):
    # Desktop Entry Exec has its own quoting rules, not shell quoting.
    value = value.replace("%", "%%")
    for char in ("\\", '"', "`", "$"):
        value = value.replace(char, "\\" + char)
    return '"' + value + '"'


def metadata(root, fallback):
    name, icon_name = fallback, ""
    for entry in sorted(root.glob("*.desktop")):
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        try:
            parser.read(entry, encoding="utf-8")
            section = parser["Desktop Entry"]
            name = section.get("Name", fallback)
            icon_name = section.get("Icon", "")
            break
        except (OSError, UnicodeError, configparser.Error, KeyError):
            continue
    candidates = [root / ".DirIcon"]
    if icon_name:
        relative_icon = Path(icon_name.lstrip("/"))
        if ".." not in relative_icon.parts:
            candidates += [root / relative_icon]
            candidates += [root / (icon_name + ext) for ext in (".png", ".svg", ".xpm")]
            candidates += sorted((root / "usr/share/icons").glob("**/" + relative_icon.name + ".*"))
            candidates += sorted((root / "usr/share/pixmaps").glob(relative_icon.name + ".*"))
    for icon in candidates:
        try:
            resolved = icon.resolve()
            if resolved.is_relative_to(root.resolve()) and resolved.is_file():
                if resolved.suffix.lower() in (".png", ".svg", ".xpm"):
                    return name, resolved
        except OSError:
            pass
    return name, None


def integrate(applications, data, cache, runner):
    applications.mkdir(parents=True, exist_ok=True)
    entries = data / "applications"
    icons = data / "icons/hicolor/256x256/apps"
    entries.mkdir(parents=True, exist_ok=True)
    icons.mkdir(parents=True, exist_ok=True)
    cache.mkdir(parents=True, exist_ok=True)
    state_file = cache / "state.json"
    try:
        old_state = json.loads(state_file.read_text())
    except (OSError, ValueError):
        old_state = {}
    state = {}
    present = set()
    changed = False
    for image in sorted(applications.iterdir()):
        if image.suffix.lower() != ".appimage" or image.is_symlink() or not image.is_file():
            continue
        key = PREFIX + hashlib.sha256(str(image).encode()).hexdigest()[:20]
        present.add(key)
        stat = image.stat()
        fingerprint = [stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns, runner]
        entry = entries / (key + ".desktop")
        if old_state.get(key) == fingerprint and entry.exists():
            state[key] = fingerprint
            continue
        # Avoid extracting a file while it is still being downloaded/copied.
        if time.time() - stat.st_mtime < 2:
            if key in old_state:
                state[key] = old_state[key]
            continue
        try:
            with tempfile.TemporaryDirectory(prefix="extract-", dir=cache) as work:
                root = Path(work) / "image"
                subprocess.run(
                    [runner, "-x", str(root), str(image)], check=True,
                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=120,
                )
                name, icon = metadata(root, image.stem)
                icon_value = "application-x-executable"
                if icon:
                    destination = icons / (key + icon.suffix.lower())
                    shutil.copyfile(icon, destination)
                    icon_value = str(destination)
                text = "\n".join([
                    "[Desktop Entry]", "Type=Application",
                    "Name=" + desktop_value(name),
                    "Exec=" + desktop_value(exec_arg(runner) + " " + exec_arg(str(image))),
                    "Icon=" + desktop_value(icon_value),
                    "Terminal=false", "Categories=Utility;", "",
                ])
                temporary = entry.with_suffix(".tmp")
                temporary.write_text(text)
                temporary.replace(entry)
                state[key] = fingerprint
                changed = True
                print(f"Integrated {image.name}: {name}", flush=True)
        except (OSError, subprocess.SubprocessError) as error:
            print(f"Cannot integrate {image}: {error}", flush=True)
            if key in old_state:
                state[key] = old_state[key]
    for entry in entries.glob(PREFIX + "*.desktop"):
        if entry.stem not in present:
            entry.unlink()
            for icon in icons.glob(entry.stem + ".*"):
                icon.unlink()
            changed = True
    temporary = state_file.with_suffix(".tmp")
    temporary.write_text(json.dumps(state))
    temporary.replace(state_file)
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runner", required=True)
    parser.add_argument("--applications", type=Path, default=Path.home() / "Applications")
    parser.add_argument("--data", type=Path, default=Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))))
    parser.add_argument("--cache", type=Path, default=Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "appimage-integration")
    args = parser.parse_args()
    if integrate(args.applications, args.data, args.cache, args.runner):
        subprocess.run(["update-desktop-database", str(args.data / "applications")], check=False)


if __name__ == "__main__":
    main()
