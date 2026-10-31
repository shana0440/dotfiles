import json
import unittest

from playback_monitor import PlaybackState, documents


def node(node_id, state="running", media_class="Stream/Output/Audio"):
    return {
        "id": node_id,
        "type": "PipeWire:Interface:Node",
        "info": {"state": state, "props": {"media.class": media_class}},
    }


class PlaybackStateTests(unittest.TestCase):
    def test_running_playback(self):
        self.assertTrue(PlaybackState().apply([node(1)]))

    def test_capture_and_devices_do_not_count(self):
        events = [
            node(1, media_class="Stream/Input/Audio"),  # Includes CAVA's capture stream.
            node(2, media_class="Audio/Sink"),
            node(3, media_class="Audio/Source"),
        ]
        self.assertFalse(PlaybackState().apply(events))

    def test_partial_state_changes_keep_the_media_class(self):
        state = PlaybackState()
        self.assertTrue(state.apply([node(1)]))
        for value in ["idle", "suspended", "error"]:
            self.assertFalse(state.apply([{"id": 1, "info": {"state": value}}]))
        self.assertTrue(state.apply([{"id": 1, "info": {"state": "running"}}]))

    def test_partial_property_updates_keep_state_and_class(self):
        state = PlaybackState()
        state.apply([node(1)])
        self.assertTrue(state.apply([{"id": 1, "info": {"props": {"node.name": "changed"}}}]))
        self.assertFalse(state.apply([{"id": 1, "info": {"props": {"media.class": "Stream/Input/Audio"}}}]))

    def test_removing_the_last_stream_stops_playback(self):
        state = PlaybackState()
        state.apply([node(1)])
        self.assertFalse(state.apply([{"id": 1, "info": None}]))

    def test_multiple_streams(self):
        state = PlaybackState()
        state.apply([node(1), node(2)])
        self.assertTrue(state.apply([{"id": 1, "info": None}]))
        self.assertFalse(state.apply([{"id": 2, "info": {"state": "idle"}}]))

    def test_reused_id_does_not_keep_an_old_stream(self):
        state = PlaybackState()
        state.apply([node(1)])
        self.assertFalse(state.apply([{"id": 1, "type": "PipeWire:Interface:Client", "info": {}}]))

    def test_initial_empty_snapshot(self):
        self.assertFalse(PlaybackState().apply([]))

    def test_changes_are_applied_as_one_batch(self):
        state = PlaybackState()
        state.apply([node(1)])
        self.assertTrue(state.apply([{"id": 1, "info": None}, node(2)]))


class DocumentTests(unittest.TestCase):
    def test_consecutive_documents(self):
        self.assertEqual(list(documents([b"[]\n", b"[{}]\n"])), [[], [{}]])

    def test_partial_json_and_utf8(self):
        value = [{"name": "音楽", "info": {"state": "running"}}]
        payload = json.dumps(value, ensure_ascii=False).encode("utf-8") + b"\n[]\n"
        self.assertEqual(list(documents([bytes([byte]) for byte in payload])), [value, []])

    def test_truncated_document(self):
        with self.assertRaises(ValueError):
            list(documents([b'[{"id": 1']))


if __name__ == "__main__":
    unittest.main()
