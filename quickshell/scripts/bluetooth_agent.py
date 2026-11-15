#!/usr/bin/env python3
import asyncio
import itertools
import json
import sys

from dbus_next import BusType, DBusError, Message, MessageType
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method

AGENT_PATH = "/org/dotfiles/quickshell/BluetoothAgent"
CAPABILITY = "KeyboardDisplay"
REJECTED = "org.bluez.Error.Rejected"
CANCELED = "org.bluez.Error.Canceled"


def emit(payload):
    print(json.dumps(payload), flush=True)


class Agent(ServiceInterface):
    def __init__(self, bus):
        super().__init__("org.bluez.Agent1")
        self.bus = bus
        self.ids = itertools.count(1)
        self.pending = {}

    async def device_name(self, path):
        reply = await self.bus.call(Message(
            destination="org.bluez", path=path,
            interface="org.freedesktop.DBus.Properties", member="Get",
            signature="ss", body=["org.bluez.Device1", "Alias"]))
        if reply.message_type == MessageType.METHOD_RETURN:
            return reply.body[0].value
        return path.rsplit("/", 1)[-1].removeprefix("dev_").replace("_", ":")

    async def ask_quickshell(self, kind, device, **extra):
        request_id = next(self.ids)
        future = asyncio.get_running_loop().create_future()
        self.pending[request_id] = future
        emit({"id": request_id, "type": kind, "device": device,
              "name": await self.device_name(device), **extra})
        try:
            reply = await future
        finally:
            self.pending.pop(request_id, None)
        if not reply.get("accept"):
            raise DBusError(REJECTED, "Rejected by user")
        return reply.get("value", "")

    def reply(self, payload):
        future = self.pending.get(payload.get("id"))
        if future and not future.done():
            future.set_result(payload)

    def cancel_all(self):
        for future in self.pending.values():
            if not future.done():
                future.set_exception(DBusError(CANCELED, "Canceled"))
        emit({"type": "cancel"})

    async def tell_quickshell(self, kind, device, **extra):
        emit({"id": next(self.ids), "type": kind, "device": device,
              "name": await self.device_name(device), **extra})

    @method()
    def Release(self):
        self.cancel_all()

    @method()
    async def RequestPinCode(self, device: "o") -> "s":
        return await self.ask_quickshell("pin", device)

    @method()
    async def DisplayPinCode(self, device: "o", pincode: "s"):
        await self.tell_quickshell("display-pin", device, passkey=pincode)

    @method()
    async def RequestPasskey(self, device: "o") -> "u":
        value = await self.ask_quickshell("passkey", device)
        try:
            return int(value)
        except ValueError:
            raise DBusError(REJECTED, "Passkey must be numeric")

    @method()
    async def DisplayPasskey(self, device: "o", passkey: "u", entered: "q"):
        await self.tell_quickshell("display-passkey", device, passkey=f"{passkey:06d}", entered=entered)

    @method()
    async def RequestConfirmation(self, device: "o", passkey: "u"):
        await self.ask_quickshell("confirm", device, passkey=f"{passkey:06d}")

    @method()
    async def RequestAuthorization(self, device: "o"):
        await self.ask_quickshell("authorize", device)

    @method()
    async def AuthorizeService(self, device: "o", uuid: "s"):
        await self.ask_quickshell("service", device, uuid=uuid)

    @method()
    def Cancel(self):
        self.cancel_all()


async def register(bus):
    for member, signature, body in (
        ("RegisterAgent", "os", [AGENT_PATH, CAPABILITY]),
        ("RequestDefaultAgent", "o", [AGENT_PATH]),
    ):
        reply = await bus.call(Message(
            destination="org.bluez", path="/org/bluez",
            interface="org.bluez.AgentManager1", member=member,
            signature=signature, body=body))
        if reply.message_type == MessageType.ERROR and reply.error_name != "org.bluez.Error.AlreadyExists":
            print(f"{member} failed: {reply.error_name} {reply.body}", file=sys.stderr, flush=True)
            return False
    return True


async def read_replies_until_quickshell_exits(agent):
    loop = asyncio.get_running_loop()
    reader = asyncio.StreamReader()
    await loop.connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
    while line := await reader.readline():
        try:
            agent.reply(json.loads(line))
        except (ValueError, AttributeError):
            print(f"Invalid reply: {line!r}", file=sys.stderr, flush=True)


async def main():
    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
    agent = Agent(bus)
    bus.export(AGENT_PATH, agent)

    def reregister_when_bluez_restarts(message):
        if (message.message_type == MessageType.SIGNAL
                and message.member == "NameOwnerChanged"
                and message.body and message.body[0] == "org.bluez"
                and message.body[2]):
            asyncio.ensure_future(register(bus))

    bus.add_message_handler(reregister_when_bluez_restarts)
    await bus.call(Message(
        destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
        interface="org.freedesktop.DBus", member="AddMatch", signature="s",
        body=["type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.bluez'"]))
    await register(bus)
    await read_replies_until_quickshell_exits(agent)


if __name__ == "__main__":
    asyncio.run(main())
