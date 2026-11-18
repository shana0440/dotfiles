#!/usr/bin/env python3
import asyncio
import os
import sys
from urllib.parse import unquote, urlsplit

from dbus_next import Message, MessageType, Variant
from dbus_next.aio import MessageBus

PORTAL = "org.freedesktop.portal.Desktop"
IMAGE_GLOBS = ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.svg"]


async def main():
    title = sys.argv[1] if len(sys.argv) > 1 else "Choose an image"
    bus = await MessageBus().connect()
    token = f"pick_image_{os.getpid()}"
    sender = bus.unique_name.lstrip(":").replace(".", "_")
    handle = f"/org/freedesktop/portal/desktop/request/{sender}/{token}"
    response = asyncio.get_running_loop().create_future()

    def on_message(message):
        if (message.message_type == MessageType.SIGNAL and message.path == handle
                and message.member == "Response" and not response.done()):
            response.set_result(message.body)

    bus.add_message_handler(on_message)
    await bus.call(Message(
        destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
        interface="org.freedesktop.DBus", member="AddMatch", signature="s",
        body=[f"type='signal',interface='org.freedesktop.portal.Request',member='Response',path='{handle}'"]))
    reply = await bus.call(Message(
        destination=PORTAL, path="/org/freedesktop/portal/desktop",
        interface="org.freedesktop.portal.FileChooser", member="OpenFile", signature="ssa{sv}",
        body=["", title, {
            "handle_token": Variant("s", token),
            "modal": Variant("b", True),
            "filters": Variant("a(sa(us))", [["Images", [[0, glob] for glob in IMAGE_GLOBS]]]),
        }]))
    if reply.message_type == MessageType.ERROR:
        sys.exit(f"file chooser failed: {reply.error_name} {reply.body}")

    code, results = await response
    uris = results.get("uris")
    if code == 0 and uris and uris.value and os.path.isfile(unquote(urlsplit(uris.value[0]).path)):
        print(uris.value[0])


asyncio.run(main())
