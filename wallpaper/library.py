"""Wallpaper picker backend; external tools are provided by wallpaper.nix."""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

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


def set_wallpaper(image):
    subprocess.run(["awww", "img", str(image), "--transition-type", "fade",
                    "--transition-duration", "0.35"], check=True, timeout=5)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "set":
        if len(sys.argv) != 3:
            raise ValueError("Usage: wallpaper-set IMAGE")
        image = Path(sys.argv[2]).expanduser().resolve(strict=True)
        if not image.is_file() or image.suffix.lower() not in EXTENSIONS:
            raise ValueError("Choose a JPG, PNG, or WebP image")
        set_wallpaper(image)
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
