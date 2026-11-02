import unittest

from launcher_badges import Badges


class BadgeTests(unittest.TestCase):
    def setUp(self):
        self.badges = Badges()
        self.sender = ":1.42"
        self.uri = "application://org.telegram.desktop.desktop"
        self.desktop_id = "org.telegram.desktop.desktop"

    def update(self, **properties):
        return self.badges.update(self.sender, self.uri, properties)

    def state(self):
        return self.badges.snapshot()[self.desktop_id]

    def test_count_requires_visibility(self):
        self.update(count=4)
        self.assertEqual(self.state()["count"], 0)
        self.update(**{"count-visible": True})
        self.assertEqual(self.state()["count"], 4)

    def test_partial_updates_preserve_count(self):
        self.update(**{"count": 7, "count-visible": True})
        self.update(urgent=True)
        self.assertEqual(self.state(), {"count": 7, "urgent": True})

    def test_visibility_false_hides_but_preserves_count(self):
        self.update(**{"count": 7, "count-visible": True})
        self.update(**{"count-visible": False})
        self.assertEqual(self.state()["count"], 0)
        self.update(**{"count-visible": True})
        self.assertEqual(self.state()["count"], 7)

    def test_count_and_urgency_clear_independently(self):
        self.update(**{"count": 3, "count-visible": True, "urgent": True})
        self.update(count=0)
        self.assertEqual(self.state(), {"count": 0, "urgent": True})
        self.update(urgent=False)
        self.assertEqual(self.state(), {"count": 0, "urgent": False})

    def test_negative_counts_clear(self):
        self.update(**{"count": 3, "count-visible": True})
        self.update(count=-1)
        self.assertEqual(self.state()["count"], 0)

    def test_invalid_values_do_not_override_state(self):
        self.update(**{"count": 3, "count-visible": True, "urgent": True})
        self.assertFalse(self.update(**{"count": True, "count-visible": 0, "urgent": "false"}))
        self.assertEqual(self.state(), {"count": 3, "urgent": True})

    def test_duplicate_and_unrelated_updates_are_ignored(self):
        self.assertFalse(self.update(progress=0.5))
        self.assertTrue(self.update(count=1))
        self.assertFalse(self.update(count=1))

    def test_invalid_uris_are_ignored(self):
        for uri in ("file://app.desktop", "application://app", "application://[",
                    "application://dir/app.desktop", "application://app.desktop?x=1",
                    "application://app.desktop#fragment"):
            with self.subTest(uri=uri):
                self.assertFalse(self.badges.update(self.sender, uri, {"urgent": True}))
        self.assertEqual(self.badges.snapshot(), {})

    def test_percent_encoded_desktop_ids(self):
        self.badges.update(self.sender, "application://my%2Dapp.desktop", {"urgent": True})
        self.assertTrue(self.badges.snapshot()["my-app.desktop"]["urgent"])

    def test_publisher_exit_clears_only_its_state(self):
        self.update(urgent=True)
        self.badges.update(":1.43", "application://discord.desktop", {"urgent": True})
        self.assertTrue(self.badges.remove_sender(self.sender))
        self.assertNotIn(self.desktop_id, self.badges.snapshot())
        self.assertIn("discord.desktop", self.badges.snapshot())
        self.assertFalse(self.badges.remove_sender(self.sender))

    def test_multiple_publishers_do_not_clear_each_other(self):
        self.update(**{"count": 3, "count-visible": True})
        self.badges.update(":1.43", self.uri, {"urgent": True})
        self.assertEqual(self.state(), {"count": 3, "urgent": True})
        self.badges.remove_sender(self.sender)
        self.assertEqual(self.state(), {"count": 0, "urgent": True})


if __name__ == "__main__":
    unittest.main()
