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
            library, "outline_transition", return_value=False
        ), patch.dict(os.environ, {"XDG_CACHE_HOME": str(self.cache)}), patch.object(library.subprocess, "run") as run:
            library.main()
        self.assertEqual(run.call_args.args[0][:3], ["awww", "img", str(image)])
        self.assertTrue(run.call_args.kwargs["check"])

    def test_set_propagates_daemon_failure(self):
        image = self.image()
        with patch.object(sys, "argv", ["library", "set", str(image)]), patch.object(
            library, "outline_transition", return_value=False
        ), patch.dict(os.environ, {"XDG_CACHE_HOME": str(self.cache)}), patch.object(
            library.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "awww")
        ):
            with self.assertRaises(subprocess.CalledProcessError):
                library.main()

    def test_cold_outline_cache_uses_fade_without_ipc(self):
        response = subprocess.CompletedProcess([], 0, stdout='{"ready":false}')
        with patch.object(library.subprocess, "run", return_value=response), patch.object(library, "transition_ipc") as ipc:
            self.assertFalse(library.outline_transition(self.source / "new.png"))
        ipc.assert_not_called()

    def test_prepared_outline_waits_for_ready_and_completion(self):
        field = subprocess.CompletedProcess([], 0, stdout='{"ready":true,"map":"/tmp/map.png"}')
        outputs = subprocess.CompletedProcess([], 0, stdout=json.dumps({"": [{"name": "screen", "displaying": {"image": "/old.png"}}]}))
        with patch.object(library.subprocess, "run", side_effect=[field, outputs]), patch.object(
            library, "transition_ipc", side_effect=["42", '{"phase":"ready"}', "ok", '{"phase":"done"}']
        ) as ipc, patch.object(library.time, "sleep"):
            self.assertTrue(library.outline_transition(self.source / "new.png"))
        self.assertEqual([c.args[0] for c in ipc.call_args_list], ["prepare", "status", "go", "status"])

    def test_failed_renderer_is_aborted_before_fallback(self):
        field = subprocess.CompletedProcess([], 0, stdout='{"ready":true,"map":"/tmp/map.png"}')
        outputs = subprocess.CompletedProcess([], 0, stdout=json.dumps({"": [{"displaying": {"image": "/old.png"}}]}))
        with patch.object(library.subprocess, "run", side_effect=[field, outputs]), patch.object(
            library, "transition_ipc", side_effect=["42", '{"phase":"error","error":"bad shader"}', ""]
        ) as ipc:
            self.assertFalse(library.outline_transition(self.source / "new.png"))
        self.assertEqual(ipc.call_args.args, ("abort", "42"))

    def test_first_wallpaper_solid_background_uses_fade(self):
        field = subprocess.CompletedProcess([], 0, stdout='{"ready":true,"map":"/tmp/map.png"}')
        outputs = subprocess.CompletedProcess([], 0, stdout=json.dumps({"": [{"displaying": {"color": [0, 0, 0]}}]}))
        with patch.object(library.subprocess, "run", side_effect=[field, outputs]), patch.object(library, "transition_ipc") as ipc:
            self.assertFalse(library.outline_transition(self.source / "new.png"))
        ipc.assert_not_called()

    def test_successful_outline_does_not_apply_a_second_fade(self):
        with patch.object(library, "outline_transition", return_value=True), patch.dict(
            os.environ, {"XDG_CACHE_HOME": str(self.cache)}
        ), patch.object(library.subprocess, "run") as run:
            library.set_wallpaper(self.source / "new.png")
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
