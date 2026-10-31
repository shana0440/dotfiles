import codecs
import json
import signal
import subprocess
import sys
import time

NODE_TYPE = "PipeWire:Interface:Node"
OUTPUT_STREAM = "Stream/Output/Audio"
JSON_READ_SIZE = 65536
MAX_INCOMPLETE_JSON_SIZE = 16 * 1024 * 1024
PIPEWIRE_RECONNECT_DELAY_SECONDS = 1
PROCESS_EXIT_TIMEOUT_SECONDS = 2


def iter_json_documents(chunks):
    """pw-dump emits consecutive JSON arrays over a chunked UTF-8 pipe."""
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
        if len(buffer) > MAX_INCOMPLETE_JSON_SIZE:
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
            if "state" in info:
                node["state"] = info["state"]
            props = info.get("props")
            if isinstance(props, dict) and "media.class" in props:
                node["media.class"] = props["media.class"]
        return any(
            node.get("media.class") == OUTPUT_STREAM and node.get("state") == "running"
            for node in self.nodes.values()
        )


def exit_on_signal(_signal, _frame):
    raise SystemExit(0)


def main():
    signal.signal(signal.SIGTERM, exit_on_signal)
    signal.signal(signal.SIGINT, exit_on_signal)
    last_playing = None

    def publish_if_changed(playing):
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
            chunks = iter(lambda: process.stdout.read(JSON_READ_SIZE), b"")
            for events in iter_json_documents(chunks):
                publish_if_changed(state.apply(events))
            raise RuntimeError(f"pw-dump exited with status {process.wait()}")
        except BrokenPipeError:
            return
        except (OSError, ValueError, RuntimeError) as error:
            publish_if_changed(False)
            print(f"pipewire-playback-monitor: {error}", file=sys.stderr, flush=True)
        finally:
            if process is not None:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=PROCESS_EXIT_TIMEOUT_SECONDS)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                process.stdout.close()
        time.sleep(PIPEWIRE_RECONNECT_DELAY_SECONDS)


if __name__ == "__main__":
    main()
