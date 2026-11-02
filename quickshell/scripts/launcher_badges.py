#!/usr/bin/env python3
"""Stream Unity LauncherEntry badge state as JSON lines for Quickshell."""

import asyncio
import json
import sys
from urllib.parse import unquote, urlsplit


class Badges:
    def __init__(self):
        self.entries = {}

    def update(self, sender, uri, properties):
        try:
            url = urlsplit(uri)
        except ValueError:
            return False
        if url.scheme != "application" or url.query or url.fragment:
            return False
        desktop_id = unquote(url.netloc + url.path)
        if not desktop_id.endswith(".desktop") or "/" in desktop_id or not sender:
            return False
        key = (sender, desktop_id)
        entry = dict(self.entries.get(key, {}))
        for field in ("count", "count-visible", "urgent"):
            if field not in properties:
                continue
            value = properties[field]
            if field == "count" and type(value) is int:
                entry[field] = max(0, value)
            elif field != "count" and type(value) is bool:
                entry[field] = value
        if not entry or entry == self.entries.get(key):
            return False
        self.entries[key] = entry
        return True

    def remove_sender(self, sender):
        removed = [key for key in self.entries if key[0] == sender]
        for key in removed:
            del self.entries[key]
        return bool(removed)

    def snapshot(self):
        # Multiple publishers may advertise one desktop ID. Keep attention from
        # any live publisher rather than letting one erase another's state.
        result = {}
        for (_, desktop_id), entry in self.entries.items():
            count = entry.get("count", 0) if entry.get("count-visible", False) else 0
            badge = result.setdefault(desktop_id, {"count": 0, "urgent": False})
            badge["count"] = max(badge["count"], count)
            badge["urgent"] |= entry.get("urgent", False)
        return result


def emit(badges=None):
    print(json.dumps(badges.snapshot() if badges else {}), flush=True)


async def monitor():
    from dbus_next import Message, MessageType
    from dbus_next.aio import MessageBus

    bus = await MessageBus().connect()
    badges = Badges()

    def receive(message):
        if message.message_type != MessageType.SIGNAL:
            return
        changed = False
        if (message.interface == "com.canonical.Unity.LauncherEntry"
                and message.member == "Update" and message.signature == "sa{sv}"):
            uri, properties = message.body
            changed = badges.update(message.sender, uri, {
                key: value.value for key, value in properties.items()
            })
        elif (message.sender == "org.freedesktop.DBus"
              and message.interface == "org.freedesktop.DBus"
              and message.member == "NameOwnerChanged" and message.signature == "sss"):
            name, old_owner, new_owner = message.body
            if name.startswith(":") and old_owner and not new_owner:
                changed = badges.remove_sender(old_owner)
        if changed:
            emit(badges)

    bus.add_message_handler(receive)
    try:
        for rule in (
            "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged'",
            "type='signal',interface='com.canonical.Unity.LauncherEntry',member='Update'", 
        ):
            reply = await bus.call(Message(
                destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                interface="org.freedesktop.DBus", member="AddMatch",
                signature="s", body=[rule],
            ))
            if reply.message_type == MessageType.ERROR:
                raise RuntimeError(f"AddMatch failed: {reply.body}")
        emit(badges)
        await bus.wait_for_disconnect()
    finally:
        bus.disconnect()
        emit()


async def main():
    while True:
        try:
            await monitor()
        except Exception as error:
            print(f"launcher-badge-monitor: {error}", file=sys.stderr, flush=True)
            emit()
        await asyncio.sleep(2)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
