"""GPU-only BiRefNet inference for wallpaper outline maps.

Model: ZhengPeng7/BiRefNet (MIT), general-lite ONNX export from rembg.
Inspired by pocket-dots' outline-first transitions; implemented independently.
"""
import json
import os
from pathlib import Path
import sys


def gpu_session():
    import onnxruntime as ort
    if "CUDAExecutionProvider" not in ort.get_available_providers():
        raise RuntimeError("CUDAExecutionProvider unavailable; CPU inference is disabled")
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    session = ort.InferenceSession(os.environ["WALLPAPER_MODEL"], sess_options=options,
        providers=[("CUDAExecutionProvider", {
            "cudnn_conv_algo_search": "HEURISTIC",
            "arena_extend_strategy": "kSameAsRequested",
        })])
    session.disable_fallback()
    if "CUDAExecutionProvider" not in session.get_providers():
        raise RuntimeError("CUDA initialization failed; CPU inference is disabled")
    return session


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "doctor":
        session = gpu_session()
        print(json.dumps({"providers": session.get_providers(), "model": os.environ["WALLPAPER_MODEL"]}))
    else:
        raise ValueError("Usage: wallpaper-outline doctor")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
