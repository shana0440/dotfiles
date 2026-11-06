"""Open a Wine-translated path in the native Linux file manager."""

import json
from pathlib import Path
import subprocess
import sys


def reveal(filename):
    target = Path(filename).absolute()
    method = 'ShowFolders' if target.is_dir() else 'ShowItems'
    try:
        result = subprocess.run([
            'gdbus', 'call', '--session', '--dest', 'org.freedesktop.FileManager1',
            '--object-path', '/org/freedesktop/FileManager1', '--method',
            f'org.freedesktop.FileManager1.{method}',
            json.dumps([target.as_uri()]), '',
        ], capture_output=True, timeout=10)
        if result.returncode == 0:
            return
    except (OSError, subprocess.TimeoutExpired):
        pass
    # Managers without the standard D-Bus interface still open the folder.
    folder = target if target.is_dir() else target.parent
    subprocess.run(['xdg-open', str(folder)], check=True)


if __name__ == '__main__':
    reveal(sys.argv[1])
