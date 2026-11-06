import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

from integrate import PREFIX, exec_arg, integrate


class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.apps = self.root / "Applications"
        self.apps.mkdir()
        self.data = self.root / "data"
        self.cache = self.root / "cache"
        self.runner = self.root / "fake-runner"
        self.runner.write_text(f"#!{sys.executable}\n" + '''
import pathlib, sys
root = pathlib.Path(sys.argv[2])
if pathlib.Path(sys.argv[3]).read_text() == "broken":
    sys.exit(1)
root.mkdir()
(root / "app.desktop").write_text("[Desktop Entry]\\nName=Example App\\nIcon=example\\nExec=DO-NOT-IMPORT-THIS\\n")
(root / "example.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg"/>')
''')
        self.runner.chmod(0o755)

    def image(self, name="Example.AppImage", content="valid"):
        image = self.apps / name
        image.write_text(content)
        os.utime(image, (1, 1))
        return image

    def scan(self):
        return integrate(self.apps, self.data, self.cache, str(self.runner))

    def entries(self):
        return list((self.data / "applications").glob(PREFIX + "*.desktop"))

    def test_add_update_remove_and_preserve_unrelated_entries(self):
        image = self.image('Example 100% "quoted".AppImage')
        self.assertTrue(self.scan())
        entry = self.entries()[0]
        text = entry.read_text()
        self.assertIn("Name=Example App\n", text)
        self.assertNotIn("DO-NOT-IMPORT-THIS", text)
        self.assertIn("100%%", text)
        self.assertEqual(len(list((self.data / "icons").rglob("*.svg"))), 1)
        self.assertFalse(self.scan())
        image.write_text("new-version")
        os.utime(image, (1, 1))
        self.assertTrue(self.scan())
        unrelated = entry.parent / "other.desktop"
        unrelated.write_text("keep me")
        image.unlink()
        self.assertTrue(self.scan())
        self.assertEqual(self.entries(), [])
        self.assertTrue(unrelated.exists())
        self.assertEqual(list((self.data / "icons").rglob("*.svg")), [])

    def test_failed_update_preserves_entry_and_retries(self):
        image = self.image()
        self.scan()
        before = self.entries()[0].read_text()
        image.write_text("broken")
        os.utime(image, (1, 1))
        self.assertFalse(self.scan())
        self.assertEqual(self.entries()[0].read_text(), before)
        image.write_text("fixed")
        os.utime(image, (1, 1))
        self.assertTrue(self.scan())

    def test_incomplete_download_is_retried(self):
        image = self.image()
        os.utime(image, None)
        self.assertFalse(self.scan())
        self.assertEqual(self.entries(), [])
        os.utime(image, (1, 1))
        self.assertTrue(self.scan())

    def test_ignore_symlinks_and_other_files(self):
        other = self.apps / "incomplete.AppImage.part"
        other.write_text("incomplete")
        (self.apps / "linked.AppImage").symlink_to(other)
        self.assertFalse(self.scan())
        self.assertEqual(self.entries(), [])

    def test_runner_change_rebuilds_entries(self):
        self.image()
        self.scan()
        state = json.loads((self.cache / "state.json").read_text())
        self.assertEqual(next(iter(state.values()))[-1], str(self.runner))
        other = self.root / "new-runner"
        other.write_bytes(self.runner.read_bytes())
        other.chmod(0o755)
        self.assertTrue(integrate(self.apps, self.data, self.cache, str(other)))
        self.assertIn(str(other), self.entries()[0].read_text())

    def test_exec_quoting(self):
        self.assertEqual(exec_arg('/a b/$c`d"e%'), '"/a b/\\$c\\`d\\"e%%"')


if __name__ == "__main__":
    unittest.main()
