import fcntl
import heapq
import json
import os
from pathlib import Path
import random
import sys
import tempfile
import time

WIDTH, HEIGHT = 384, 216
POOL = 8
SECONDS_FOR_RENDERER_TO_RELEASE_MAP = 3
VERSION = "colonies-v1"


def pool_dir():
    base = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    return base / "wallpaper" / "colonies" / VERSION


def _noise(rng, width, height, scale):
    import numpy as np
    from PIL import Image
    lattice = rng.random((max(2, int(height / scale) + 2), max(2, int(width / scale) + 2)))
    image = Image.fromarray((lattice * 65535).astype(np.uint16).astype(np.int32), mode="I")
    image = image.resize((width, height), Image.Resampling.BICUBIC)
    return np.clip(np.asarray(image, dtype=np.float64) / 65535, 0, 1)


def _blur(field, sigma):
    import numpy as np
    radius = int(3 * sigma) + 1
    kernel = np.exp(-np.arange(-radius, radius + 1) ** 2 / (2 * sigma * sigma))
    kernel /= kernel.sum()
    padded = np.pad(field, radius, mode="edge")
    rows = sum(w * padded[:, i:i + field.shape[1]] for i, w in enumerate(kernel))
    return sum(w * rows[i:i + field.shape[0], :] for i, w in enumerate(kernel))


def _shortest_arrival(cost, seeds, width, height):
    inf = float("inf")
    arrival = [inf] * (width * height)
    heap = []
    for index, start in seeds:
        if start < arrival[index]:
            arrival[index] = start
            heap.append((start, index))
    heapq.heapify(heap)
    steps = ((1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0),
             (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (-1, -1, 1.4142))
    while heap:
        now, index = heapq.heappop(heap)
        if now > arrival[index]:
            continue
        y, x = divmod(index, width)
        here = cost[index]
        for dx, dy, length in steps:
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height:
                other = ny * width + nx
                candidate = now + (here + cost[other]) * 0.5 * length
                if candidate < arrival[other]:
                    arrival[other] = candidate
                    heapq.heappush(heap, (candidate, other))
    return arrival


def make_map(seed, width=WIDTH, height=HEIGHT):
    import numpy as np
    rng = np.random.default_rng(seed)
    valleys_steering_colonies = _noise(rng, width, height, rng.uniform(30, 60))
    medium_detail = _noise(rng, width, height, rng.uniform(8, 16))
    fraying_edge_detail = _noise(rng, width, height, rng.uniform(2, 4))
    noise = 0.45 * valleys_steering_colonies + 0.35 * medium_detail + 0.20 * fraying_edge_detail
    noise = (noise - noise.min()) / max(noise.max() - noise.min(), 1e-9)
    crisp_edge_grain = np.exp(rng.normal(0, rng.uniform(0.5, 0.8), (height, width)))
    tendril_contrast = rng.uniform(7.0, 10.0)
    cost = (0.05 + np.exp(tendril_contrast * (noise - 0.5))) * crisp_edge_grain
    colonies = int(rng.integers(6, 11))
    diagonal = (width * width + height * height) ** 0.5
    seeds = []
    for _ in range(colonies):
        x = int(rng.uniform(0.06, 0.94) * width)
        y = int(rng.uniform(0.08, 0.92) * height)
        seeds.append((y * width + x, float(rng.uniform(0, 0.15 * diagonal))))
    arrival = np.asarray(_shortest_arrival(cost.ravel().tolist(), seeds, width, height))
    order = np.empty(arrival.size)
    order[np.argsort(arrival, kind="stable")] = np.arange(arrival.size)
    share_of_screen_changed_before = (order / (arrival.size - 1)).reshape(height, width)
    packed = np.round(share_of_screen_changed_before * 65535).astype(np.uint16)
    rgb = np.zeros((height, width, 3), np.uint8)
    rgb[..., 0] = packed >> 8
    rgb[..., 1] = packed & 255
    rgb[..., 2] = np.clip(np.round(_blur(share_of_screen_changed_before, 2.5) * 255), 0, 255).astype(np.uint8)
    return rgb


def _write(path, rgb):
    from PIL import Image
    fd, temp = tempfile.mkstemp(dir=path.parent, suffix=".png")
    os.close(fd)
    try:
        Image.fromarray(rgb, "RGB").save(temp)
        os.replace(temp, path)
    finally:
        Path(temp).unlink(missing_ok=True)


def _slot(index):
    return pool_dir() / f"map-{index}.png"


def _locked(index):
    directory = pool_dir()
    directory.mkdir(parents=True, exist_ok=True)
    lock = (directory / f"map-{index}.lock").open("w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    return lock


def generate(index):
    with _locked(index):
        _write(_slot(index), make_map(random.randrange(1 << 31)))


def warm():
    directory = pool_dir()
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / "warm.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        for index in range(POOL):
            if not _slot(index).is_file():
                generate(index)


def take():
    ready = [i for i in range(POOL) if _slot(i).is_file()]
    index = random.choice(ready) if ready else random.randrange(POOL)
    if not ready:
        generate(index)
    return str(_slot(index))


def accent(image_path):
    import colorsys
    from PIL import Image
    with Image.open(image_path) as image:
        small = image.convert("RGB")
        small.thumbnail((96, 96))
    palette = small.quantize(colors=8, method=Image.Quantize.MEDIANCUT).convert("RGB")
    best, best_score = (1.0, 0.6, 0.3), -1.0
    for _, (r, g, b) in palette.getcolors(96 * 96):
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        score = s * (1 - abs(2 * l - 1))
        if score > best_score:
            best, best_score = (h, l, s), score
    h, l, s = best
    r, g, b = colorsys.hls_to_rgb(h, min(max(l, 0.62), 0.80), max(s, 0.55))
    return "#{:02x}{:02x}{:02x}".format(round(r * 255), round(g * 255), round(b * 255))


def is_pool_slot(path):
    return path.parent == pool_dir() and path.stem.startswith("map-")


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "warm":
        warm()
    elif command == "take":
        print(take())
    elif command == "renew" and len(sys.argv) == 3:
        path = Path(sys.argv[2])
        if is_pool_slot(path):
            time.sleep(SECONDS_FOR_RENDERER_TO_RELEASE_MAP)
            generate(int(path.stem.split("-")[1]) % POOL)
    elif command == "accent" and len(sys.argv) == 3:
        print(accent(sys.argv[2]))
    elif command == "time":
        start = time.monotonic()
        make_map(1)
        print(json.dumps({"seconds": round(time.monotonic() - start, 3)}))
    else:
        raise SystemExit("Usage: wallpaper-colonies warm|take|renew MAP|accent IMAGE|time")


if __name__ == "__main__":
    main()
