import json
import shutil
import stat
import subprocess
import sys
from pathlib import Path
from tempfile import mkdtemp
from urllib.parse import unquote, urlsplit

IMAGE_TYPES = dict(zip(
    ("image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp"),
    (".png", ".jpg", ".webp", ".gif", ".bmp"),
))
IMAGES = set(IMAGE_TYPES.values()) | {".jpeg"}
RECORDINGS = {".mp4", ".webm", ".mkv", ".mov"}
FILE_TYPES = ("x-special/gnome-copied-files", "text/uri-list")
IMAGE_LIMIT = 20 * 1024**2
RECORDING_LIMIT = 250 * 1024**2


def clipboard(*args):
    return subprocess.run(["wl-paste", *args], capture_output=True, timeout=5, check=True).stdout


def copied_file(mime):
    lines = clipboard("--no-newline", "--type", mime).decode().splitlines()
    if mime == FILE_TYPES[0] and lines and lines[0] in ("copy", "cut"):
        lines.pop(0)
    uris = [line for line in lines if line and not line.startswith("#")]
    if len(uris) != 1:
        raise ValueError("Paste one image or recording at a time.")
    uri = urlsplit(uris[0])
    if uri.scheme != "file" or uri.netloc not in ("", "localhost") or not uri.path.startswith("/"):
        raise ValueError("Only local image and recording files can be pasted.")
    return Path(unquote(uri.path))


def save_attachment(folder):
    try:
        types = clipboard("--list-types").decode().splitlines()
    except subprocess.CalledProcessError:
        return {}

    image_type = next((mime for mime in IMAGE_TYPES if mime in types), None)
    file_type = next((mime for mime in FILE_TYPES if mime in types), None)
    if not image_type and not file_type:
        return {}

    source = None if image_type else copied_file(file_type)
    extension = IMAGE_TYPES[image_type] if image_type else source.suffix.lower()
    if extension not in IMAGES | RECORDINGS:
        raise ValueError("That file isn't a supported image or recording.")
    kind = "image" if extension in IMAGES else "recording"
    limit = IMAGE_LIMIT if kind == "image" else RECORDING_LIMIT
    if source is not None:
        info = source.stat()
        if not stat.S_ISREG(info.st_mode) or not info.st_size:
            raise ValueError("The copied file is empty or unavailable.")
        if info.st_size > limit:
            raise ValueError(f"The {kind} is larger than {limit // 1024**2} MiB.")

    folder.mkdir(mode=0o700, parents=True, exist_ok=True)
    directory = Path(mkdtemp(prefix="paste-", dir=folder))
    target = directory / (kind + extension)
    try:
        if source is None:
            with target.open("wb") as output, subprocess.Popen(
                ["wl-paste", "--no-newline", "--type", image_type], stdout=output, stderr=subprocess.DEVNULL
            ) as paste:
                try:
                    if paste.wait(timeout=5) != 0:
                        raise ValueError("Couldn't read the copied image.")
                except subprocess.TimeoutExpired:
                    paste.kill()
                    raise
        else:
            shutil.copyfile(source, target)
        size = target.stat().st_size
        if not size or size > limit:
            raise ValueError(f"The {kind} is empty or larger than {limit // 1024**2} MiB.")
    except BaseException:
        shutil.rmtree(directory)
        raise
    return {"kind": kind, "path": str(target), "url": target.as_uri()}


def main():
    folder = Path(sys.argv[1]).absolute() / "state" / "sessions" / "attachments"
    if len(sys.argv) > 2:
        path = Path(sys.argv[2])
        if path.parent.parent == folder and path.parent.name.startswith("paste-"):
            path.unlink(missing_ok=True)
            if path.parent.is_dir():
                path.parent.rmdir()
        return
    try:
        print(json.dumps(save_attachment(folder)))
    except ValueError as error:
        print(json.dumps({"error": str(error)}))
    except (OSError, subprocess.SubprocessError):
        print(json.dumps({"error": "Couldn't read or save the copied attachment."}))


if __name__ == "__main__":
    main()
