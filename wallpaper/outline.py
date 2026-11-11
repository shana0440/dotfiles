"""GPU-only BiRefNet inference and cached maps for outline-first wallpapers.

Model: ZhengPeng7/BiRefNet_lite (MIT), pinned dynamic ONNX export from senty-au.
Inspired by pocket-dots' outline-first transitions; implemented independently.
"""
import argparse
import collections
import fcntl
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import time

VERSION = "outline-v3-birefnet-lite-fp16-cuda512-173d6359"
EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
SESSION = None


def cache_dir():
    return Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "wallpaper/outlines"


def identity(image):
    image = Path(image).expanduser().resolve(strict=True)
    stat = image.stat()
    key = hashlib.sha256(f"{VERSION}|{image}|{stat.st_mtime_ns}|{stat.st_size}".encode()).hexdigest()
    return image, key


def cached(image):
    image, key = identity(image)
    base = cache_dir() / key
    try:
        result = json.loads(base.with_suffix(".json").read_text())
        if result["ready"] and not Path(result["map"]).is_file():
            return None
        return result
    except (OSError, ValueError, KeyError):
        return None


def atomic_json(path, data):
    fd, tmp = tempfile.mkstemp(dir=path.parent, suffix=".json")
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream)
        os.replace(tmp, path)
    finally:
        Path(tmp).unlink(missing_ok=True)


def atomic_image(path, image):
    fd, tmp = tempfile.mkstemp(dir=path.parent, suffix=".png")
    os.close(fd)
    try:
        image.save(tmp)
        os.replace(tmp, path)
    finally:
        Path(tmp).unlink(missing_ok=True)


def gpu_session(profile=False):
    import onnxruntime as ort
    ort.set_default_logger_severity(3)
    if "CUDAExecutionProvider" not in ort.get_available_providers():
        raise RuntimeError("CUDAExecutionProvider unavailable; CPU inference is disabled")
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.enable_profiling = profile
    options.log_severity_level = 3
    options.enable_mem_pattern = False
    if profile:
        cache_dir().mkdir(parents=True, exist_ok=True)
        options.profile_file_prefix = str(cache_dir() / "cuda-check")
    session = ort.InferenceSession(os.environ["WALLPAPER_MODEL"], sess_options=options,
        providers=[("CUDAExecutionProvider", {
            "cudnn_conv_algo_search": "HEURISTIC",
            "arena_extend_strategy": "kSameAsRequested",
            "cudnn_conv_use_max_workspace": "0",
        })])
    session.disable_fallback()
    if "CUDAExecutionProvider" not in session.get_providers():
        raise RuntimeError("CUDA initialization failed; CPU inference is disabled")
    return session


def predict(image, session):
    import numpy as np
    from PIL import Image
    # The Nix build fixes the dynamic model to 512px for desktop VRAM headroom.
    rgb = np.asarray(image.resize((512, 512), Image.Resampling.LANCZOS), dtype=np.float32) / 255
    rgb = (rgb - np.array([0.485, 0.456, 0.406], np.float32)) / np.array([0.229, 0.224, 0.225], np.float32)
    tensor = np.ascontiguousarray(rgb.transpose(2, 0, 1)[None])
    logits = session.run(None, {session.get_inputs()[0].name: tensor})[0].squeeze()
    probability = 1 / (1 + np.exp(-np.clip(logits, -60, 60)))
    low, high = float(probability.min()), float(probability.max())
    probability = (probability - low) / max(high - low, 1e-6)
    return Image.fromarray((probability * 255).astype(np.uint8)).resize(image.size, Image.Resampling.LANCZOS)


def make_map(mask):
    """RGB: signed edge distance, stroke arrival, inward/outward reveal order.

    No alpha: Qt premultiplies alpha textures, which would corrupt map values.
    Returns (map or None, metrics). This part never performs model inference.
    """
    import cv2
    import numpy as np
    from PIL import Image
    probability = np.asarray(mask, dtype=np.float32) / 255
    binary = (probability > 0.5).astype(np.uint8)
    h, w = binary.shape
    count, labels, stats, _ = cv2.connectedComponentsWithStats(binary, 8)
    keep = np.zeros(count, dtype=bool)
    keep[1:] = stats[1:, cv2.CC_STAT_AREA] >= w * h * 0.002
    binary = keep[labels].astype(np.uint8)
    coverage = float(binary.mean())
    uncertain = float(((probability > 0.1) & (probability < 0.9)).mean())
    metrics = {"coverage": coverage, "uncertain": uncertain, "width": w, "height": h}
    if not (0.008 <= coverage <= 0.80 and uncertain <= 0.10):
        return None, metrics

    inward = cv2.distanceTransform(binary, cv2.DIST_L2, 5)
    outward = cv2.distanceTransform(1 - binary, cv2.DIST_L2, 5)
    signed = inward - outward
    edge = np.zeros((h, w), np.uint8)
    arrival = np.ones((h, w), np.float32)
    contours, _ = cv2.findContours(binary, cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE)
    for contour in contours:
        if len(contour) < 32 or abs(cv2.contourArea(contour)) < w * h * 0.0005:
            continue
        points = contour[:, 0].astype(np.float32)
        # Arclength, starting at the top; two strokes meet halfway around.
        lengths = np.linalg.norm(np.roll(points, -1, axis=0) - points, axis=1)
        distance = np.r_[0, np.cumsum(lengths)[:-1]]
        perimeter = max(float(lengths.sum()), 1)
        distance = (distance - distance[np.argmin(points[:, 1])]) % perimeter
        progress = 0.01 + 0.98 * np.minimum(distance, perimeter - distance) / (perimeter / 2)
        xy = points.astype(int)
        x, y = xy[:, 0], xy[:, 1]
        # A subject cropped by the image border has no visible contour there.
        progress[(x <= 1) | (x >= w - 2) | (y <= 1) | (y >= h - 2)] = 1
        edge[y, x] = 1
        arrival[y, x] = progress
    if not edge.any():
        return None, metrics
    _, nearest = cv2.distanceTransformWithLabels(1 - edge, cv2.DIST_L2, 5,
                                                labelType=cv2.DIST_LABEL_PIXEL)
    table = np.r_[1, arrival[edge > 0]]
    phase = table[nearest]
    # B < .5 fills the character; B >= .5 brings the world outwards.
    inner_order = inward / max(float(inward.max()), 1) * 0.49
    outer_order = 0.51 + outward / max(float(outward.max()), 1) * 0.49
    order = np.where(binary > 0, inner_order, outer_order)
    rgb = np.stack([np.clip(0.5 + signed / 64, 0, 1), phase, order], axis=-1)
    return Image.fromarray((rgb * 255 + 0.5).astype(np.uint8)), metrics


def prepare(image):
    global SESSION
    image, key = identity(image)
    directory = cache_dir()
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / f"{key}.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        result = cached(image)
        if result is not None:
            return result
        from PIL import Image, ImageOps
        start = time.monotonic()
        with Image.open(image) as source:
            picture = ImageOps.exif_transpose(source).convert("RGB")
        picture.thumbnail((1280, 1280))
        if SESSION is None:
            SESSION = gpu_session()
        mask = predict(picture, SESSION)
        field, metrics = make_map(mask)
        result = {"ready": field is not None, "image": str(image), "version": VERSION,
                  "provider": "CUDAExecutionProvider", "seconds": round(time.monotonic() - start, 3), **metrics}
        if field is not None:
            map_path = directory / f"{key}.png"
            atomic_image(map_path, field)
            result["map"] = str(map_path)
        else:
            result["reason"] = "No sufficiently clear foreground subject"
        atomic_json(directory / f"{key}.json", result)
        return result


def warm(directory):
    directory = Path(directory).expanduser()
    if not directory.is_dir():
        return
    cache_dir().mkdir(parents=True, exist_ok=True)
    with (cache_dir() / "warm.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        for image in sorted(directory.iterdir()):
            if image.is_file() and image.suffix.lower() in EXTENSIONS:
                try:
                    print(json.dumps(prepare(image)), flush=True)
                except Exception as error:
                    print(f"{image.name}: {error}", file=sys.stderr, flush=True)
                    # A CUDA failure must not retry the model for every image.
                    if SESSION is None or type(error).__module__.startswith("onnxruntime"):
                        raise


def doctor():
    from PIL import Image
    session = gpu_session(profile=True)
    predict(Image.new("RGB", (128, 128)), session)
    profile_path = Path(session.end_profiling())
    events = json.loads(profile_path.read_text())
    counts = collections.Counter(e.get("args", {}).get("provider") for e in events if e.get("cat") == "Node")
    cuda_convolutions = sum(1 for e in events if e.get("args", {}).get("provider") == "CUDAExecutionProvider"
                            and "Conv" in e.get("args", {}).get("op_name", ""))
    profile_path.unlink(missing_ok=True)
    cpu_compute = [e.get("args", {}).get("op_name") for e in events
                   if e.get("args", {}).get("provider") == "CPUExecutionProvider"
                   and e.get("args", {}).get("op_name") in {"Conv", "FusedConv", "MatMul", "Gemm", "GridSample"}]
    if not cuda_convolutions or cpu_compute:
        raise RuntimeError(f"GPU verification failed: CUDA convolutions={cuda_convolutions}, CPU compute={cpu_compute}")
    print(json.dumps({"providers": session.get_providers(), "kernels": dict(counts),
                      "cudaConvolutions": cuda_convolutions, "model": os.environ["WALLPAPER_MODEL"]}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["doctor", "prepare", "cached", "warm"])
    parser.add_argument("image", nargs="?")
    args = parser.parse_args()
    if args.command == "doctor":
        doctor()
    elif args.command == "warm":
        warm(args.image or os.environ["WALLPAPER_DIR"])
    elif not args.image:
        parser.error("image path required")
    else:
        result = cached(args.image) if args.command == "cached" else prepare(args.image)
        print(json.dumps(result or {"ready": False, "reason": "Not prepared"}))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
