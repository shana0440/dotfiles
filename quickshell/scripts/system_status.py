"""Read one host-status snapshot; CPU utilization is derived between snapshots in QML."""

import json
import os
from pathlib import Path


def read_text(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return None


def cpu_times():
    # guest/guest_nice are already included in user/nice; do not count twice.
    fields = Path("/proc/stat").read_text().splitlines()[0].split()[1:9]
    values = [int(value) for value in fields]
    return {"total": sum(values), "idle": values[3] + values[4]}


def memory():
    values = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        name, value = line.split(":", 1)
        values[name] = int(value.split()[0]) * 1024
    return {
        "total": values["MemTotal"],
        "used": values["MemTotal"] - values["MemAvailable"],
        "swapTotal": values["SwapTotal"],
        "swapUsed": values["SwapTotal"] - values["SwapFree"],
    }


def temperature():
    sensors = []
    for directory in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
        name = read_text(directory / "name") or "Sensor"
        for path in sorted(directory.glob("temp*_input")):
            raw = read_text(path)
            try:
                degrees = float(raw) / 1000
            except (TypeError, ValueError):
                continue
            if not -20 <= degrees <= 150:
                continue
            label = read_text(path.with_name(path.name.replace("_input", "_label"))) or name
            cpu = name in {"coretemp", "k10temp", "zenpower", "cpu_thermal"} or "cpu" in name.lower()
            sensors.append({"celsius": degrees, "label": label, "cpu": cpu})
    # Prefer a CPU sensor; otherwise identify the actual hottest available sensor.
    candidates = [sensor for sensor in sensors if sensor["cpu"]] or sensors
    return max(candidates, key=lambda sensor: sensor["celsius"], default=None)


def storage():
    disks = []
    seen = set()
    for label, path in [("Root", "/"), ("Home", str(Path.home()))]:
        try:
            device = os.stat(path).st_dev
            stats = os.statvfs(path)
        except OSError:
            continue
        if device in seen:
            continue
        seen.add(device)
        total = stats.f_blocks * stats.f_frsize
        free = stats.f_bavail * stats.f_frsize
        used = (stats.f_blocks - stats.f_bfree) * stats.f_frsize
        # Match df: exclude blocks reserved for root from user-available capacity.
        capacity = used + free
        disks.append({"label": label, "path": path, "total": total, "used": used,
                      "free": free, "percent": used / capacity if capacity else 0})
    return disks


def snapshot():
    return {
        "cpu": cpu_times(),
        "memory": memory(),
        "temperature": temperature(),
        "storage": storage(),
        "load": list(os.getloadavg()),
        "cores": os.cpu_count() or 1,
        "uptime": int(float(Path("/proc/uptime").read_text().split()[0])),
    }


if __name__ == "__main__":
    print(json.dumps(snapshot(), allow_nan=False))
