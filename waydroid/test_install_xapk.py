import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import install_xapk


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.source = self.root / "game bundle.xapk"
        self.destination = self.root / "unpacked"
        self.destination.mkdir()
        self.manifest = {
            "xapk_version": 2,
            "package_name": "com.example.game",
            "name": "Example game",
            "split_apks": [{"file": "base.apk"}, {"file": "config.arm64_v8a.apk"}],
        }

    def bundle(self, manifest=None, files=None):
        with zipfile.ZipFile(self.source, "w") as archive:
            archive.writestr("manifest.json", json.dumps(self.manifest if manifest is None else manifest))
            for name, content in (files or {"base.apk": b"base bytes", "config.arm64_v8a.apk": b"split bytes"}).items():
                archive.writestr(name, content)

    def test_extracts_all_declared_splits_in_order(self):
        self.bundle()
        bundle = install_xapk.unpack_bundle(self.source, self.destination)
        self.assertEqual(bundle.name, "Example game")
        self.assertEqual(bundle.package, "com.example.game")
        self.assertEqual([path.read_bytes() for path in bundle.apks], [b"base bytes", b"split bytes"])
        self.assertTrue(all(path.parent == self.destination for path in bundle.apks))

    def test_rejects_malformed_json(self):
        with zipfile.ZipFile(self.source, "w") as archive:
            archive.writestr("manifest.json", "not JSON")
        with self.assertRaises(json.JSONDecodeError):
            install_xapk.unpack_bundle(self.source, self.destination)

    def test_rejects_traversal_before_extracting(self):
        self.manifest["split_apks"] = [{"file": "../outside.apk"}]
        self.bundle(files={"../outside.apk": b"bad"})
        with self.assertRaises(ValueError):
            install_xapk.unpack_bundle(self.source, self.destination)
        self.assertEqual(list(self.destination.iterdir()), [])
        self.assertFalse((self.root / "outside.apk").exists())

    def test_rejects_duplicate_splits(self):
        self.manifest["split_apks"].append({"file": "base.apk"})
        self.bundle()
        with self.assertRaises(ValueError):
            install_xapk.unpack_bundle(self.source, self.destination)

    def test_rejects_missing_split(self):
        self.bundle(files={"base.apk": b"base"})
        with self.assertRaises(KeyError):
            install_xapk.unpack_bundle(self.source, self.destination)
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_rejects_obb_before_installation_or_extraction(self):
        self.bundle(files={"base.apk": b"base", "config.arm64_v8a.apk": b"split", "Android/obb/com.example.game/main.obb": b"data"})
        with self.assertRaisesRegex(ValueError, "OBB"):
            install_xapk.unpack_bundle(self.source, self.destination)
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_rejects_oversized_apk_payload(self):
        self.bundle()
        with patch.object(install_xapk, "MAX_APK_BYTES", 4):
            with self.assertRaises(ValueError):
                install_xapk.unpack_bundle(self.source, self.destination)
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_rejects_empty_split_list(self):
        self.manifest["split_apks"] = []
        self.bundle()
        with self.assertRaises(ValueError):
            install_xapk.unpack_bundle(self.source, self.destination)

    def test_rejects_unsupported_version_or_invalid_name(self):
        for field, value in [("xapk_version", 3), ("name", ""), ("name", 7)]:
            with self.subTest(field=field, value=value):
                manifest = {**self.manifest, field: value}
                self.bundle(manifest=manifest)
                with self.assertRaises(ValueError):
                    install_xapk.unpack_bundle(self.source, self.destination)

    def test_rejects_oversized_manifest(self):
        self.bundle()
        with patch.object(install_xapk, "MAX_MANIFEST_BYTES", 4):
            with self.assertRaises(ValueError):
                install_xapk.unpack_bundle(self.source, self.destination)

    def test_rejects_symlink_apk(self):
        self.manifest["split_apks"] = [{"file": "base.apk"}]
        with zipfile.ZipFile(self.source, "w") as archive:
            archive.writestr("manifest.json", json.dumps(self.manifest))
            entry = zipfile.ZipInfo("base.apk")
            entry.create_system = 3
            entry.external_attr = 0o120777 << 16
            archive.writestr(entry, "../../outside")
        with self.assertRaises(ValueError):
            install_xapk.unpack_bundle(self.source, self.destination)
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_rejects_duplicate_archive_entries(self):
        self.bundle()
        with zipfile.ZipFile(self.source, "a") as archive:
            with self.assertWarns(UserWarning):
                archive.writestr("base.apk", b"duplicate")
        with self.assertRaises(ValueError):
            install_xapk.unpack_bundle(self.source, self.destination)

    def test_rejects_invalid_package_name(self):
        self.manifest["package_name"] = "not a package; command"
        self.bundle()
        with self.assertRaises(ValueError):
            install_xapk.unpack_bundle(self.source, self.destination)


class EndpointTests(unittest.TestCase):
    def test_selects_only_live_waydroid_lease(self):
        leases = "99 aa:bb:cc:dd:ee:ff 192.168.240.100 old *\n200 aa:bb:cc:dd:ee:00 192.168.240.112 WayDroid *\n"
        self.assertEqual(install_xapk.waydroid_endpoint(leases, 100), "192.168.240.112:5555")

    def test_rejects_ambiguous_devices(self):
        with self.assertRaises(ValueError):
            install_xapk.waydroid_endpoint("200 aa 192.168.240.2 a *\n200 bb 192.168.240.3 b *", 100)

    def test_rejects_invalid_address(self):
        with self.assertRaises(ValueError):
            install_xapk.waydroid_endpoint("200 aa not-an-ip a *", 100)

    def test_accepts_infinite_lease(self):
        self.assertEqual(install_xapk.waydroid_endpoint("0 aa 192.168.240.112 WayDroid *", 100), "192.168.240.112:5555")

    def test_rejects_malformed_lease(self):
        with self.assertRaises(ValueError):
            install_xapk.waydroid_endpoint("200 aa 192.168.240.112", 100)

    def test_waits_for_an_active_lease_during_startup(self):
        self.assertIsNone(install_xapk.waydroid_endpoint("", 100))
        self.assertIsNone(install_xapk.waydroid_endpoint("99 aa 192.168.240.2 old *", 100))


class DialogTests(unittest.TestCase):
    def test_cancel_is_not_an_installer_error_even_with_gtk_warnings(self):
        result = subprocess.CompletedProcess(["zenity"], 1, "", "GTK warning\n")
        with patch.object(install_xapk.subprocess, "run", return_value=result):
            self.assertIs(install_xapk.dialog("question", "Install?"), False)

    def test_unexpected_dialog_exit_propagates(self):
        result = subprocess.CompletedProcess(["zenity"], 255, "", "tool error")
        with patch.object(install_xapk.subprocess, "run", return_value=result):
            with self.assertRaises(subprocess.CalledProcessError):
                install_xapk.dialog("question", "Install?")


if __name__ == "__main__":
    unittest.main()
