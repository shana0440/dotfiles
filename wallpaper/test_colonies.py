"""Colony map tests; run via wallpaper-check (dependencies from wallpaper.nix)."""
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import numpy as np
from PIL import Image

spec = importlib.util.spec_from_file_location("colonies", sys.argv.pop(1))
colonies = importlib.util.module_from_spec(spec)
spec.loader.exec_module(colonies)


def arrival(rgb):
    return (rgb[..., 0].astype(int) * 256 + rgb[..., 1]) / 65535


class ColonyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        patcher = patch.dict(os.environ, {"XDG_CACHE_HOME": self.temp.name})
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_area_grows_evenly_over_the_whole_screen(self):
        moment = arrival(colonies.make_map(7, 96, 54))
        self.assertAlmostEqual(moment.min(), 0)
        self.assertAlmostEqual(moment.max(), 1)
        for t in (0.1, 0.5, 0.9):
            self.assertAlmostEqual((moment <= t).mean(), t, delta=0.01)

    def test_colonies_form_connected_regions_not_noise(self):
        moment = arrival(colonies.make_map(3, 96, 54))
        early = moment < 0.3
        # Most early cells border other early cells: spreading fronts, not speckle.
        neighbours = early[1:-1, 1:-1] & (early[:-2, 1:-1] | early[2:, 1:-1] | early[1:-1, :-2] | early[1:-1, 2:])
        self.assertGreater(neighbours.sum() / max(early[1:-1, 1:-1].sum(), 1), 0.95)

    def test_maps_differ_by_seed_and_glow_channel_is_smooth(self):
        a, b = colonies.make_map(1, 96, 54), colonies.make_map(2, 96, 54)
        self.assertFalse(np.array_equal(a, b))
        glow = a[..., 2].astype(float)
        self.assertLess(np.abs(np.diff(glow, axis=1)).mean(), np.abs(np.diff(a[..., 0].astype(float), axis=1)).mean() + 1)

    def test_take_fills_an_empty_pool_and_reuses_existing_maps(self):
        small = colonies.make_map(5, 48, 27)
        with patch.object(colonies, "make_map", return_value=small):
            path = Path(colonies.take())
            self.assertTrue(path.is_file())
            with Image.open(path) as image:
            self.assertEqual(image.mode, "RGB")
            with patch.object(colonies, "generate", side_effect=AssertionError("pool should be reused")):
                self.assertEqual(colonies.take(), str(path))

    def test_warm_fills_every_slot_atomically(self):
        with patch.object(colonies, "make_map", return_value=np.zeros((2, 2, 3), np.uint8)):
            colonies.warm()
        files = sorted(p.name for p in colonies.pool_dir().glob("*.png"))
        self.assertEqual(files, sorted(f"map-{i}.png" for i in range(colonies.POOL)))
        self.assertEqual(list(colonies.pool_dir().glob("*.tmp*")), [])

    def test_accent_picks_the_vivid_colour_and_lifts_dark_ones(self):
        image = Path(self.temp.name) / "art # one.png"
        canvas = Image.new("RGB", (64, 64), (20, 20, 24))
        canvas.paste((90, 0, 10), (0, 0, 20, 20))       # dark but vivid red
        canvas.save(image)
        colour = colonies.accent(image)
        r, g, b = (int(colour[i:i + 2], 16) for i in (1, 3, 5))
        self.assertGreater(r, 150)
        self.assertGreater(r, g + 60)


if __name__ == "__main__":
    unittest.main()
