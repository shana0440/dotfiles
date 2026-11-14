"""Run via wallpaper-check; all dependencies come from wallpaper.nix."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("library", sys.argv.pop(1))
library = importlib.util.module_from_spec(spec)
spec.loader.exec_module(library)


class LibraryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "walls"
        self.source.mkdir()
        self.cache = self.root / "cache"
        # `set` records the current wallpaper; keep that out of the real state dir.
        state = patch.dict(os.environ, {"XDG_STATE_HOME": str(self.root / "state")})
        state.start()
        self.addCleanup(state.stop)

    def image(self, name="wallpaper # ' one.PNG"):
        path = self.source / name
        subprocess.run(["magick", "-size", "64x36", "xc:purple", str(path)], check=True)
        return path

    def test_missing_directory_is_empty(self):
        result = library.catalog(self.root / "missing", self.cache)
        self.assertEqual(result["items"], [])
        self.assertEqual(result["errors"], [])

    def test_supported_files_sorted_and_bad_images_reported(self):
        self.image("b.PNG")
        self.image("A.jpg")
        (self.source / "notes.txt").write_text("ignored")
        (self.source / "broken.png").write_text("not an image")
        result = library.catalog(self.source, self.cache)
        self.assertEqual([item["name"] for item in result["items"]], ["A.jpg", "b.PNG"])
        self.assertEqual(len(result["errors"]), 1)

    def test_special_names_and_cached_thumbnail(self):
        image = self.image()
        first = library.catalog(self.source, self.cache)
        self.assertEqual(first["items"][0]["path"], str(image))
        thumb = next(self.cache.glob("*.jpg"))
        mtime = thumb.stat().st_mtime_ns
        with patch.object(library.subprocess, "run", side_effect=AssertionError("unexpected conversion")):
            self.assertEqual(library.catalog(self.source, self.cache), first)
        self.assertEqual(thumb.stat().st_mtime_ns, mtime)

    def test_changed_image_replaces_thumbnail(self):
        image = self.image()
        first = library.catalog(self.source, self.cache)
        stat = image.stat()
        os.utime(image, ns=(stat.st_atime_ns, stat.st_mtime_ns + 1000000))
        second = library.catalog(self.source, self.cache)
        self.assertNotEqual(first["items"][0]["thumbnail"], second["items"][0]["thumbnail"])
        self.assertEqual(len(list(self.cache.glob("*.jpg"))), 1)

    def test_deleted_image_prunes_cache(self):
        image = self.image()
        library.catalog(self.source, self.cache)
        image.unlink()
        self.assertEqual(library.catalog(self.source, self.cache)["items"], [])
        self.assertEqual(list(self.cache.glob("*.jpg")), [])

    def test_failed_conversion_leaves_no_partial_thumbnail(self):
        self.image()
        with patch.object(library.subprocess, "run", side_effect=subprocess.TimeoutExpired("magick", 30)):
            result = library.catalog(self.source, self.cache)
        self.assertEqual(result["items"], [])
        self.assertEqual(len(result["errors"]), 1)
        self.assertEqual(list(self.cache.iterdir()), [])

    def test_set_passes_filename_as_single_argument(self):
        image = self.image()
        with patch.object(sys, "argv", ["library", "set", str(image)]), patch.object(
            library, "colony_transition", return_value=False
        ), patch.dict(os.environ, {"XDG_CACHE_HOME": str(self.cache)}), patch.object(library.subprocess, "run") as run:
            library.main()
        self.assertEqual(run.call_args.args[0][:3], ["awww", "img", str(image)])
        self.assertTrue(run.call_args.kwargs["check"])

    def test_set_records_current_wallpaper(self):
        image = self.image()
        state = Path(os.environ["XDG_STATE_HOME"])
        with patch.object(sys, "argv", ["library", "set", str(image)]), patch.object(
            library, "set_wallpaper"
        ):
            library.main()
        self.assertEqual((state / "wallpaper/current").read_text(), f"{image}\n")
        self.assertEqual([p.name for p in (state / "wallpaper").iterdir()], ["current"])

    def test_failed_set_keeps_previous_record(self):
        image = self.image()
        state = Path(os.environ["XDG_STATE_HOME"])
        (state / "wallpaper").mkdir(parents=True)
        (state / "wallpaper/current").write_text("/old.png\n")
        with patch.object(sys, "argv", ["library", "set", str(image)]), patch.object(
            library, "set_wallpaper", side_effect=subprocess.CalledProcessError(1, "awww")
        ):
            with self.assertRaises(subprocess.CalledProcessError):
                library.main()
        self.assertEqual((state / "wallpaper/current").read_text(), "/old.png\n")

    def test_set_propagates_daemon_failure(self):
        image = self.image()
        with patch.object(sys, "argv", ["library", "set", str(image)]), patch.object(
            library, "colony_transition", return_value=False
        ), patch.dict(os.environ, {"XDG_CACHE_HOME": str(self.cache)}), patch.object(
            library.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "awww")
        ):
            with self.assertRaises(subprocess.CalledProcessError):
                library.main()


    def query(self, displaying):
        return subprocess.CompletedProcess([], 0, stdout=json.dumps({"": [{"name": "A", "displaying": displaying}]}))

    def test_colony_transition_waits_for_ready_and_done_then_renews_map(self):
        done = [self.query({"image": "/old.png"}), subprocess.CompletedProcess([], 0, stdout="/pool/map-3.png\n"),
                subprocess.CompletedProcess([], 0, stdout="#ff8800\n")]
        with patch.object(library.subprocess, "run", side_effect=done) as run, patch.object(
            library, "transition_ipc", side_effect=["42", '{"phase":"ready"}', "ok", '{"phase":"done"}']
        ) as ipc, patch.object(library.subprocess, "Popen") as popen, patch.object(library.time, "sleep"):
            self.assertTrue(library.colony_transition(self.source / "new.png"))
        self.assertEqual([c.args[0] for c in ipc.call_args_list], ["prepare", "status", "go", "status"])
        request = json.loads(ipc.call_args_list[0].args[1])
        self.assertEqual((request["map"], request["ember"]), ("/pool/map-3.png", "#ff8800"))
        self.assertEqual(popen.call_args.args[0], ["wallpaper-colonies", "renew", "/pool/map-3.png"])
        self.assertEqual(run.call_count, 3)

    def test_solid_colour_start_still_uses_colonies(self):
        done = [self.query({"color": [0, 0, 0]}), subprocess.CompletedProcess([], 0, stdout="/m.png"),
                subprocess.CompletedProcess([], 0, stdout="#ffffff")]
        with patch.object(library.subprocess, "run", side_effect=done), patch.object(
            library, "transition_ipc", side_effect=["1", '{"phase":"ready"}', "ok", '{"phase":"done"}']
        ), patch.object(library.subprocess, "Popen"), patch.object(library.time, "sleep"):
            self.assertTrue(library.colony_transition(self.source / "new.png"))

    def test_renderer_failure_is_aborted_and_falls_back(self):
        done = [self.query({"image": "/old.png"}), subprocess.CompletedProcess([], 0, stdout="/m.png"),
                subprocess.CompletedProcess([], 0, stdout="#ffffff")]
        with patch.object(library.subprocess, "run", side_effect=done), patch.object(
            library, "transition_ipc", side_effect=["42", '{"phase":"error","error":"bad shader"}', ""]
        ) as ipc, patch.object(library.subprocess, "Popen") as popen:
            self.assertFalse(library.colony_transition(self.source / "new.png"))
        self.assertEqual(ipc.call_args.args, ("abort", "42"))
        popen.assert_not_called()

    def test_change_already_heading_there_is_done_without_fade(self):
        done = [self.query({"image": "/old.png"}), subprocess.CompletedProcess([], 0, stdout="/m.png"),
                subprocess.CompletedProcess([], 0, stdout="#ffffff")]
        with patch.object(library.subprocess, "run", side_effect=done), patch.object(
            library, "transition_ipc", side_effect=["same"]
        ) as ipc, patch.object(library.subprocess, "Popen") as popen:
            self.assertTrue(library.colony_transition(self.source / "new.png"))
        self.assertEqual(ipc.call_count, 1)     # no go, no abort
        popen.assert_not_called()

    def test_ipc_client_does_not_inherit_quickshell_crash_state(self):
        crashed = {"__QUICKSHELL_CRASH_INFO_FD": "85", "__QUICKSHELL_CRASH_SIGNAL": "11", "KEEP": "1"}
        with patch.dict(os.environ, crashed), patch.object(
            library.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, stdout="7\n")
        ) as run:
            self.assertEqual(library.transition_ipc("status", "7"), "7")
        env = run.call_args.kwargs["env"]
        self.assertEqual(env["KEEP"], "1")
        self.assertFalse([k for k in env if k.startswith("__QUICKSHELL_CRASH_")])

    def test_missing_shell_falls_back_to_fade(self):
        done = [self.query({"image": "/old.png"}), subprocess.CompletedProcess([], 0, stdout="/m.png"),
                subprocess.CompletedProcess([], 0, stdout="#ffffff")]
        with patch.object(library.subprocess, "run", side_effect=done), patch.object(
            library, "transition_ipc", side_effect=subprocess.CalledProcessError(255, "quickshell")
        ):
            self.assertFalse(library.colony_transition(self.source / "new.png"))

    def test_successful_transition_does_not_also_fade(self):
        with patch.object(library, "colony_transition", return_value=True), patch.dict(
            os.environ, {"XDG_CACHE_HOME": str(self.cache)}
        ), patch.object(library.subprocess, "run") as run:
            library.set_wallpaper(self.source / "new.png")
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
