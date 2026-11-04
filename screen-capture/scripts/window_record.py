"""Record a native Wayland toplevel, not its rectangle on a monitor."""

import re
import signal
import subprocess
import sys
import time

FPS = 30
stopping = False


def stop(signum, frame):
    global stopping
    stopping = True


def capture(identifier):
    return subprocess.run(["grim", "-t", "ppm", "-T", identifier, "-"],
                          check=True, capture_output=True, timeout=5).stdout


def record(identifier, target):
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    frame = capture(identifier)
    header = frame.split(b"\n", 3)
    if header[0] != b"P6" or header[2] != b"255":
        raise ValueError("Unexpected native window image format")
    width, height = map(int, header[1].split())
    width, height = (width + 1) // 2 * 2, (height + 1) // 2 * 2
    # Keep the initial canvas size if the user resizes/moves the window. The
    # captured content follows the toplevel and never includes occluding apps.
    video_filter = (f"scale={width}:{height}:force_original_aspect_ratio=decrease:force_divisible_by=2,"
                    f"pad={width}:{height}:(ow-iw)/2:(oh-ih)/2,setsar=1")
    encoder = subprocess.Popen([
        "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "warning", "-y",
        "-probesize", "32", "-analyzeduration", "0", "-f", "image2pipe",
        "-framerate", str(FPS), "-vcodec", "ppm", "-i", "pipe:0",
        "-f", "pulse", "-i", "@DEFAULT_MONITOR@", "-filter_threads", "1",
        "-vf", video_filter, "-c:v", "libx264", "-preset", "superfast", "-crf", "20",
        "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", target,
    ], stdin=subprocess.PIPE)
    started = time.monotonic()
    written = 0
    try:
        while not stopping and encoder.poll() is None:
            # Duplicate frames when a capture is slow, keeping video duration in
            # real time instead of speeding it up relative to system audio.
            due = max(1, int((time.monotonic() - started) * FPS) + 1 - written)
            for _ in range(due):
                if stopping:
                    break
                encoder.stdin.write(frame)
                written += 1
            encoder.stdin.flush()
            delay = started + written / FPS - time.monotonic()
            if delay > 0:
                time.sleep(delay)
            if stopping:
                break
            try:
                frame = capture(identifier)
            except (subprocess.SubprocessError, OSError):
                # Closing/minimizing an unavailable source ends and finalizes
                # the recording rather than switching to a different window.
                if not stopping:
                    print("Selected window is no longer available; finishing recording.", file=sys.stderr)
                break
    except BrokenPipeError:
        if not stopping:
            raise RuntimeError("The window video encoder stopped unexpectedly")
    finally:
        try:
            encoder.stdin.close()
        except BrokenPipeError:
            pass
        try:
            encoder.wait(timeout=5)
        except subprocess.TimeoutExpired:
            encoder.send_signal(signal.SIGINT)
            try:
                encoder.wait(timeout=5)
            except subprocess.TimeoutExpired:
                encoder.kill()
                encoder.wait()
    if encoder.returncode not in (0, 255) and not stopping:
        raise RuntimeError(f"Window video encoder failed (exit {encoder.returncode})")


if __name__ == "__main__":
    try:
        checking = len(sys.argv) == 3 and sys.argv[1] == "--check"
        identifier = sys.argv[2] if checking else sys.argv[1]
        if not re.fullmatch(r"[0-9a-fA-F]+", identifier):
            raise ValueError("Invalid native window identifier")
        if checking:
            capture(identifier)
        elif len(sys.argv) == 3:
            record(identifier, sys.argv[2])
        else:
            raise ValueError("Expected --check IDENTIFIER or IDENTIFIER OUTPUT.mp4")
    except Exception as error:
        print(f"Window recording: {error}", file=sys.stderr)
        sys.exit(1)
