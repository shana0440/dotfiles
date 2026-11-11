"""Map/cache tests plus numerical validation of the CUDA model conversion.

The conversion test uses a NumPy mathematical reference, not CPU model inference.
Real wallpaper inference uses CUDA exclusively (wallpaper-outline doctor checks).
"""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import numpy as np
from PIL import Image, ImageDraw


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


outline = load("outline", sys.argv.pop(1))
converter = load("converter", sys.argv.pop(1))


class MapTests(unittest.TestCase):
    def mask(self):
        mask = Image.new("L", (256, 256))
        ImageDraw.Draw(mask).ellipse((64, 32, 192, 224), fill=255)
        return mask

    def test_mask_rejects_empty_full_and_uncertain_foregrounds(self):
        for value in (0, 255, 128):
            field, _ = outline.make_map(Image.new("L", (256, 256), value))
            self.assertIsNone(field)

    def test_map_encodes_edge_and_inward_outward_order_without_alpha(self):
        field, metrics = outline.make_map(self.mask())
        self.assertEqual(field.mode, "RGB")
        self.assertGreater(metrics["coverage"], 0.2)
        pixels = np.asarray(field) / 255
        self.assertGreater(pixels[128, 128, 0], 0.5)
        self.assertLess(pixels[0, 0, 0], 0.5)
        self.assertLess(pixels[128, 128, 2], 0.5)
        self.assertGreater(pixels[0, 0, 2], 0.5)
        self.assertLess(pixels[32, 128, 1], 0.1)
        self.assertGreater(pixels[224, 128, 1], 0.9)

    def test_prepared_maps_are_reused_and_image_changes_invalidate_them(self):
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, {"XDG_CACHE_HOME": temp}):
            image = Path(temp) / "wall # one.png"
            Image.new("RGB", (256, 256)).save(image)
            with patch.object(outline, "SESSION", object()), patch.object(outline, "predict", return_value=self.mask()):
                result = outline.prepare(image)
            self.assertTrue(result["ready"])
            with patch.object(outline, "gpu_session", side_effect=AssertionError("Unexpected inference")):
                self.assertEqual(outline.prepare(image), result)
            stat = image.stat()
            os.utime(image, ns=(stat.st_atime_ns, stat.st_mtime_ns + 1))
            self.assertIsNone(outline.cached(image))

    def test_missing_map_is_not_reported_ready(self):
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, {"XDG_CACHE_HOME": temp}):
            image = Path(temp) / "wall.png"
            Image.new("RGB", (256, 256)).save(image)
            with patch.object(outline, "SESSION", object()), patch.object(outline, "predict", return_value=self.mask()):
                result = outline.prepare(image)
            Path(result["map"]).unlink()
            self.assertIsNone(outline.cached(image))

    def test_gpu_initialization_failure_does_not_cache_a_bad_mask(self):
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, {"XDG_CACHE_HOME": temp}):
            image = Path(temp) / "wall.png"
            Image.new("RGB", (256, 256)).save(image)
            with patch.object(outline, "SESSION", None), patch.object(outline, "gpu_session", side_effect=RuntimeError("CUDA unavailable")):
                with self.assertRaises(RuntimeError):
                    outline.prepare(image)
            self.assertIsNone(outline.cached(image))


class ConversionTests(unittest.TestCase):
    @unittest.skipUnless(Path("/dev/nvidia0").exists(), "NVIDIA GPU required")
    def test_grid_sample_rewrite_matches_native_deform_conv(self):
        import onnx
        import onnxruntime as ort
        from onnx import helper as h, numpy_helper as nh
        rng = np.random.default_rng(42)
        # Nonzero offsets, modulation, bias, stride, dilation and padding all
        # matter: an ordinary Conv would not pass this numerical test.
        for kernel, dilation, padding in [(1, 1, 0), (3, 2, 2)]:
            k = kernel * kernel
            weights = rng.normal(0, 0.1, (2, 2, kernel, kernel)).astype(np.float32)
            bias = rng.normal(0, 0.1, 2).astype(np.float32)
            inputs = {
                "x": rng.normal(0, 0.2, (1, 2, 512, 512)).astype(np.float32),
                "offset": rng.uniform(-0.75, 0.75, (1, 2 * k, 512, 512)).astype(np.float32),
                "mask": rng.uniform(0, 1, (1, k, 512, 512)).astype(np.float32),
            }
            node = h.make_node("DeformConv", ["x", "weight", "offset", "bias", "mask"], ["out"],
                group=1, offset_group=1, strides=[1, 1], dilations=[dilation, dilation], pads=[padding] * 4)
            graph = h.make_graph([node], "reference", [h.make_tensor_value_info(n, 1, list(v.shape)) for n, v in inputs.items()],
                [h.make_tensor_value_info("out", 1, [1, 2, 512, 512])], [nh.from_array(weights, "weight"), nh.from_array(bias, "bias")])
            model = h.make_model(graph, opset_imports=[h.make_opsetid("", 19)], ir_version=10)
            with tempfile.TemporaryDirectory() as temp:
                original, converted = Path(temp) / "original.onnx", Path(temp) / "cuda.onnx"
                onnx.save(model, original)
                converter.convert(str(original), str(converted))
                # Independent NumPy bilinear sampler + convolution reference.
                picture = inputs["x"][0]
                yy, xx = np.mgrid[:512, :512]
                offsets = inputs["offset"].reshape(1, k, 2, 512, 512)[0]
                reference = np.broadcast_to(bias[:, None, None], (2, 512, 512)).copy()
                for ky in range(kernel):
                    for kx in range(kernel):
                        index = ky * kernel + kx
                        y = yy + ky * dilation - padding + offsets[index, 0]
                        x = xx + kx * dilation - padding + offsets[index, 1]
                        y0, x0 = np.floor(y).astype(int), np.floor(x).astype(int)
                        fy, fx = y - y0, x - x0
                        sampled = np.zeros_like(picture)
                        for sy, wy in [(y0, 1 - fy), (y0 + 1, fy)]:
                            for sx, wx in [(x0, 1 - fx), (x0 + 1, fx)]:
                                valid = (sy >= 0) & (sy < 512) & (sx >= 0) & (sx < 512)
                                sampled += picture[:, np.clip(sy, 0, 511), np.clip(sx, 0, 511)] * (wy * wx * valid)
                        sampled *= inputs["mask"][0, index]
                        reference += np.einsum("oc,chw->ohw", weights[:, :, ky, kx], sampled)
                reference = reference[None]
                session = ort.InferenceSession(str(converted), providers=["CUDAExecutionProvider"])
                session.disable_fallback()
                self.assertIn("CUDAExecutionProvider", session.get_providers())
                result = session.run(None, inputs)[0]
                np.testing.assert_allclose(result, reference, atol=0.001, rtol=0.005)


if __name__ == "__main__":
    unittest.main()
