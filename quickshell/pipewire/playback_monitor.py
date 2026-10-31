"""Publish playback-state changes from PipeWire as newline-delimited JSON."""

import codecs
import json
import signal
import subprocess
import sys
import time

NODE_TYPE = "PipeWire:Interface:Node"
OUTPUT_STREAM = "Stream/Output/Audio"


def documents(chunks):
    """Decode pw-dump's consecutive JSON arrays, including partial UTF-8/JSON reads."""
    utf8 = codecs.getincrementaldecoder("utf-8")()
    decoder = json.JSONDecoder()
    buffer = ""
    for chunk in chunks:
        buffer += utf8.decode(chunk)
        while buffer.strip():
            buffer = buffer.lstrip()
            try:
                document, end = decoder.raw_decode(buffer)
            except json.JSONDecodeError:
                break
            yield document
            buffer = buffer[end:]
        if len(buffer) > 16 * 1024 * 1024:
            raise ValueError("Incomplete PipeWire JSON exceeded 16 MiB")
    buffer += utf8.decode(b"", final=True)
    if buffer.strip():
        raise ValueError("Incomplete JSON at the end of the PipeWire event stream")


class PlaybackState:
    def __init__(self):
        self.nodes = {}

    def apply(self, events):
        if not isinstance(events, list):
            raise ValueError("Expected a PipeWire event array")
        for event in events:
            if not isinstance(event, dict) or not isinstance(event.get("id"), int):
                continue
            node_id = event["id"]
            info = event.get("info")
            node_type = event.get("type")
            if info is None or (node_type is not None and node_type != NODE_TYPE):
                self.nodes.pop(node_id, None)
                continue
            if not isinstance(info, dict):
                continue
            if node_type != NODE_TYPE and node_id not in self.nodes:
                continue
            node = self.nodes.setdefault(node_id, {})
            # Monitor updates can contain only the changed fields.
            if "state" in info:
                node["state"] = info["state"]
            props = info.get("props")
            if isinstance(props, dict) and "media.class" in props:
                node["media.class"] = props["media.class"]
        return any(
            node.get("media.class") == OUTPUT_STREAM and node.get("state") == "running"
            for node in self.nodes.values()
        )


def stop(_signal, _frame):
    raise SystemExit(0)


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    last_playing = None

    def publish(playing):
        nonlocal last_playing
        if playing != last_playing:
            print(json.dumps({"playing": playing}), flush=True)
            last_playing = playing

    while True:
        process = None
        try:
            process = subprocess.Popen(
                ["pw-dump", "--monitor", "--no-colors"],
                stdout=subprocess.PIPE,
                bufsize=0,
            )
            state = PlaybackState()
            chunks = iter(lambda: process.stdout.read(65536), b"")
            for events in documents(chunks):
                publish(state.apply(events))
            raise RuntimeError(f"pw-dump exited with status {process.wait()}")
        except BrokenPipeError:
            return
        except (OSError, ValueError, RuntimeError) as error:
            publish(False)
            print(f"pipewire-playback-monitor: {error}", file=sys.stderr, flush=True)
        finally:
            if process is not None:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                process.stdout.close()
        # Retry only when the connection dies; playback itself is never polled.
        time.sleep(1)


if __name__ == "__main__":
    main()
