"""Guard plain-text rendering at external text bindings."""
from pathlib import Path
import re
import unittest

CONFIG = Path(__file__).resolve().parents[1] / "config"


class ExternalTextTests(unittest.TestCase):
    def test_external_labels_are_plain_text(self):
        bindings = {
            "Bar/WifiMenu.qml": ["root.message", "ssid", "root.selectedSsid",
                'active ? "Connected" : (!security || security === "--" ? "Open" : security)'],
            "Bar/MediaView.qml": ["Services.Media.title", "Services.Media.artist",
                'root.player?.trackAlbum ?? ""'],
            "Components/Tooltip.qml": ["root.text"],
        }
        for path, expressions in bindings.items():
            source = (CONFIG / path).read_text()
            for expression in expressions:
                with self.subTest(path=path, expression=expression):
                    self.assertRegex(source, r"text: " + re.escape(expression)
                                     + r"\s+textFormat: Text\.PlainText")
