"""Integration tests; each test starts its own private D-Bus daemon."""

import asyncio
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

from dbus_next import Message, Variant
from dbus_next.aio import MessageBus


class BusTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        # Always isolate the test, even when invoked from a real desktop session.
        self.daemon = subprocess.Popen(
            ["dbus-daemon", "--session", "--nofork", "--print-address=1"],
            stdout=subprocess.PIPE, text=True,
        )
        self.address = self.daemon.stdout.readline().strip()
        self.monitor = await asyncio.create_subprocess_exec(
            sys.executable, str(Path(__file__).with_name("launcher_badges.py")),
            env={**os.environ, "DBUS_SESSION_BUS_ADDRESS": self.address},
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
        )
        self.publishers = []
        self.assertEqual(await self.read(), {})

    async def asyncTearDown(self):
        for publisher in self.publishers:
            publisher.disconnect()
            await publisher.wait_for_disconnect()
        self.monitor.terminate()
        await self.monitor.communicate()
        self.daemon.terminate()
        self.daemon.communicate(timeout=5)

    async def read(self):
        line = await asyncio.wait_for(self.monitor.stdout.readline(), 3)
        self.assertTrue(line, "monitor exited without a snapshot")
        return json.loads(line)

    async def publisher(self):
        publisher = await MessageBus(bus_address=self.address).connect()
        self.publishers.append(publisher)
        return publisher

    async def update(self, publisher, desktop_id, properties):
        await publisher.send(Message.new_signal(
            "/test/launcher", "com.canonical.Unity.LauncherEntry", "Update",
            "sa{sv}", ["application://" + desktop_id, properties],
        ))

    async def test_real_signals_partial_updates_and_publisher_exit(self):
        telegram = await self.publisher()
        discord = await self.publisher()
        await self.update(telegram, "org.telegram.desktop.desktop", {
            "count": Variant("x", 5), "count-visible": Variant("b", True),
        })
        self.assertEqual((await self.read())["org.telegram.desktop.desktop"]["count"], 5)
        await self.update(telegram, "org.telegram.desktop.desktop", {
            "count-visible": Variant("b", False),
        })
        self.assertEqual((await self.read())["org.telegram.desktop.desktop"]["count"], 0)
        await self.update(discord, "discord.desktop", {"urgent": Variant("b", True)})
        self.assertTrue((await self.read())["discord.desktop"]["urgent"])
        telegram.disconnect()
        await telegram.wait_for_disconnect()
        self.assertEqual(await self.read(), {"discord.desktop": {"count": 0, "urgent": True}})
        discord.disconnect()
        await discord.wait_for_disconnect()
        self.assertEqual(await self.read(), {})


if __name__ == "__main__":
    unittest.main()
