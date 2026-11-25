import ctypes
import os
import select
import sys
import time

import dbus

libei_path, fifo = sys.argv[1], sys.argv[2]
lib = ctypes.CDLL(libei_path)
P = ctypes.c_void_p
for name, res, args in [
    ("ei_new_sender", P, [P]), ("ei_configure_name", None, [P, ctypes.c_char_p]),
    ("ei_setup_backend_fd", ctypes.c_int, [P, ctypes.c_int]), ("ei_get_fd", ctypes.c_int, [P]),
    ("ei_dispatch", None, [P]), ("ei_get_event", P, [P]), ("ei_now", ctypes.c_uint64, [P]),
    ("ei_event_get_type", ctypes.c_int, [P]), ("ei_event_get_seat", P, [P]),
    ("ei_event_get_device", P, [P]), ("ei_event_unref", P, [P]),
    ("ei_device_ref", P, [P]), ("ei_device_has_capability", ctypes.c_bool, [P, ctypes.c_int]),
    ("ei_device_start_emulating", None, [P, ctypes.c_uint32]), ("ei_device_frame", None, [P, ctypes.c_uint64]),
    ("ei_device_pointer_motion_absolute", None, [P, ctypes.c_double, ctypes.c_double]),
    ("ei_device_button_button", None, [P, ctypes.c_uint32, ctypes.c_bool]),
    ("ei_device_scroll_discrete", None, [P, ctypes.c_int32, ctypes.c_int32]),
    ("ei_device_keyboard_key", None, [P, ctypes.c_uint32, ctypes.c_bool]),
]:
    f = getattr(lib, name)
    f.restype = res
    f.argtypes = args
lib.ei_seat_bind_capabilities.restype = None

POINTER, ABSOLUTE, KEYBOARD, SCROLL, BUTTON = 1, 2, 4, 16, 32
SEAT_ADDED, DEVICE_RESUMED = 3, 8
LEFT_BUTTON, RIGHT_BUTTON = 0x110, 0x111
KEYS = {"super": 125, "alt": 56, "ctrl": 29, "shift": 42, "space": 57, "esc": 1, "enter": 28,
        "tab": 15, "backspace": 14, "delete": 111, "up": 103, "down": 108, "left": 105, "right": 106,
        "pageup": 104, "pagedown": 109, "home": 102, "end": 107,
        "-": 12, "=": 13, "[": 26, "]": 27, ";": 39, "'": 40, "`": 41,
        "\\": 43, ",": 51, ".": 52, "/": 53}
for i, c in enumerate("1234567890"):
    KEYS[c] = 2 + i
for row, start in (("qwertyuiop", 16), ("asdfghjkl", 30), ("zxcvbnm", 44)):
    for i, c in enumerate(row):
        KEYS[c] = start + i
for i in range(1, 11):
    KEYS[f"f{i}"] = 58 + i
SHIFTED = dict(zip('!@#$%^&*()_+{}:"~|<>?', "1234567890-=[];'`\\,./"))

remote = dbus.Interface(dbus.SessionBus().get_object("org.kde.KWin", "/org/kde/KWin/EIS/RemoteDesktop"),
                        "org.kde.KWin.EIS.RemoteDesktop")
fd, _cookie = remote.connectToEIS(1 | 2)
ei = lib.ei_new_sender(None)
lib.ei_configure_name(ei, b"shell-session")
lib.ei_setup_backend_fd(ei, fd.take())
devices, sequence = {}, [1]


def pump(timeout=0.0):
    select.select([lib.ei_get_fd(ei)], [], [], timeout)
    lib.ei_dispatch(ei)
    while ev := lib.ei_get_event(ei):
        kind = lib.ei_event_get_type(ev)
        if kind == SEAT_ADDED:
            caps = [ctypes.c_int(c) for c in (POINTER, ABSOLUTE, KEYBOARD, SCROLL, BUTTON)]
            lib.ei_seat_bind_capabilities(P(lib.ei_event_get_seat(ev)), *caps, P(None))
        elif kind == DEVICE_RESUMED:
            dev = lib.ei_device_ref(lib.ei_event_get_device(ev))
            for cap in (ABSOLUTE, KEYBOARD, SCROLL, BUTTON):
                if lib.ei_device_has_capability(dev, cap):
                    devices[cap] = dev
            lib.ei_device_start_emulating(dev, sequence[0])
            sequence[0] += 1
        lib.ei_event_unref(ev)


def frame(dev):
    lib.ei_device_frame(dev, lib.ei_now(ei))
    lib.ei_dispatch(ei)


def key(code, press):
    lib.ei_device_keyboard_key(devices[KEYBOARD], code, press)
    frame(devices[KEYBOARD])


def combo(spec, hold=0.03):
    names = spec.split("+")
    for n in names:
        key(KEYS[n], True)
        time.sleep(hold)
    for n in reversed(names):
        key(KEYS[n], False)
        time.sleep(hold)


def type_char(ch):
    if ch == " ":
        combo("space", 0.01)
    elif ch in SHIFTED:
        combo("shift+" + SHIFTED[ch], 0.01)
    elif ch.isupper():
        combo("shift+" + ch.lower(), 0.01)
    else:
        combo(ch, 0.01)


def button(code, press):
    lib.ei_device_button_button(devices[BUTTON], code, press)
    frame(devices[BUTTON])


deadline = time.time() + 10
while len(devices) < 4 and time.time() < deadline:
    pump(0.1)
print("ready" if len(devices) == 4 else "missing devices", flush=True)

os.mkfifo(fifo)
while True:
    with open(fifo) as commands:
        for line in commands:
            pump()
            word, _, rest = line.rstrip("\n").partition(" ")
            if word == "move":
                x, y = map(float, rest.split())
                lib.ei_device_pointer_motion_absolute(devices[ABSOLUTE], x, y)
                frame(devices[ABSOLUTE])
            elif word in ("down", "up"):
                button(LEFT_BUTTON, word == "down")
            elif word in ("click", "rightclick"):
                code = LEFT_BUTTON if word == "click" else RIGHT_BUTTON
                button(code, True)
                time.sleep(0.05)
                button(code, False)
            elif word == "scroll":
                lib.ei_device_scroll_discrete(devices[SCROLL], 0, int(rest))
                frame(devices[SCROLL])
            elif word == "key":
                combo(rest)
            elif word in ("keydown", "keyup"):
                key(KEYS[rest], word == "keydown")
            elif word == "type":
                for ch in rest:
                    type_char(ch)
                    time.sleep(0.02)
