import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    'native_reveal', Path(__file__).with_name('native-reveal.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class NativeRevealTest(unittest.TestCase):
    @patch.object(module.subprocess, 'run')
    def test_folder_with_spaces_and_unicode(self, run):
        run.return_value.returncode = 0
        with tempfile.TemporaryDirectory(prefix='Eagle 空 格 ') as folder:
            module.reveal(folder)
            args = run.call_args.args[0]
            self.assertTrue(args[args.index('--method') + 1].endswith('.ShowFolders'))
            self.assertIn(Path(folder).as_uri(), args[-2])
            self.assertIn('%20', args[-2])
            run.assert_called_once()

    @patch.object(module.subprocess, 'run')
    def test_file_selection(self, run):
        run.return_value.returncode = 0
        module.reveal('/tmp/a "quoted" 中文.png')
        args = run.call_args.args[0]
        self.assertTrue(args[args.index('--method') + 1].endswith('.ShowItems'))
        self.assertIn('%22quoted%22', args[-2])

    @patch.object(module.subprocess, 'run')
    def test_fallback(self, run):
        run.return_value.returncode = 1
        module.reveal('/tmp/a b.png')
        self.assertEqual(run.call_args.args[0], ['xdg-open', '/tmp'])

    @patch.object(module.subprocess, 'run')
    def test_timeout_fallback_opens_directory_itself(self, run):
        run.side_effect = [subprocess.TimeoutExpired('gdbus', 10), None]
        with tempfile.TemporaryDirectory() as folder:
            module.reveal(folder)
            self.assertEqual(run.call_args.args[0], ['xdg-open', folder])


if __name__ == '__main__':
    unittest.main()
