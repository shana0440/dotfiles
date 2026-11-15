import csv
import io
import json
import math
import os
import shutil
import subprocess
import time
from pathlib import Path

KERNEL_SECTOR_BYTES = 512


def read_text(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return None


def cpu_times():
    without_guest_already_in_user_and_nice = slice(1, 9)
    fields = Path("/proc/stat").read_text().splitlines()[0].split()[without_guest_already_in_user_and_nice]
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
        capacity_without_root_reserve = used + free
        disks.append({"label": label, "path": path, "total": total, "used": used,
                      "free": free, "percent": used / capacity_without_root_reserve if capacity_without_root_reserve else 0})
    return disks


def number(value):
    try:
        parsed = float(value)
        return parsed if math.isfinite(parsed) and parsed >= 0 else None
    except (TypeError, ValueError):
        return None


def nvidia_gpus():
    executable = shutil.which("nvidia-smi")
    if not executable:
        return []
    result = subprocess.run(
        [executable, "--query-gpu=uuid,name,utilization.gpu,memory.used,memory.total,temperature.gpu",
         "--format=csv,noheader,nounits"],
        capture_output=True, text=True, check=True, timeout=1.5,
    )
    gpus = []
    for row in csv.reader(io.StringIO(result.stdout), skipinitialspace=True):
        if len(row) != 6:
            continue
        identity, name, usage, used, total, degrees = row
        usage, used, total = number(usage), number(used), number(total)
        gpus.append({"id": identity.strip(), "name": name.strip(),
                     "usage": usage / 100 if usage is not None and usage <= 100 else None,
                     "memoryUsed": used * 1024**2 if used is not None else None,
                     "memoryTotal": total * 1024**2 if total is not None else None,
                     "temperature": number(degrees)})
    return gpus


def gpus():
    devices = nvidia_gpus()
    has_nvidia = bool(devices)
    seen = set()
    for card in sorted(Path("/sys/class/drm").glob("card*")):
        if not card.name[4:].isdigit():
            continue
        device = card / "device"
        identity = str(device.resolve())
        vendor = read_text(device / "vendor")
        if not vendor or identity in seen or (vendor == "0x10de" and has_nvidia):
            continue
        seen.add(identity)
        name = {"0x1002": "AMD GPU", "0x8086": "Intel GPU", "0x10de": "NVIDIA GPU"}.get(vendor, "GPU")
        usage = number(read_text(device / "gpu_busy_percent"))
        temperatures = [number(read_text(path)) for path in device.glob("hwmon/hwmon*/temp1_input")]
        degrees = next((value / 1000 for value in temperatures if value is not None), None)
        devices.append({"id": identity, "name": name + " · " + card.name,
                        "usage": usage / 100 if usage is not None and usage <= 100 else None,
                        "memoryUsed": number(read_text(device / "mem_info_vram_used")),
                        "memoryTotal": number(read_text(device / "mem_info_vram_total")),
                        "temperature": degrees})
    return devices


def network_counters():
    interfaces = []
    for directory in sorted(Path("/sys/class/net").iterdir()):
        if directory.name == "lo" or read_text(directory / "operstate") not in {"up", "unknown"}:
            continue
        received = number(read_text(directory / "statistics/rx_bytes"))
        sent = number(read_text(directory / "statistics/tx_bytes"))
        if received is not None and sent is not None:
            interfaces.append({"id": directory.name + ":" + (read_text(directory / "ifindex") or ""),
                               "label": directory.name, "rx": received, "tx": sent})
    return interfaces


def disk_counters():
    disks = []
    for directory in sorted(Path("/sys/block").iterdir()):
        if str(directory.resolve()).startswith("/sys/devices/virtual/"):
            continue
        fields = (read_text(directory / "stat") or "").split()
        if len(fields) < 7:
            continue
        read, written = number(fields[2]), number(fields[6])
        if read is not None and written is not None:
            disks.append({"id": directory.name, "label": directory.name,
                          "read": read * KERNEL_SECTOR_BYTES, "write": written * KERNEL_SECTOR_BYTES})
    return disks


def snapshot():
    return {
        "monotonic": time.monotonic(),
        "cpu": cpu_times(),
        "network": network_counters(),
        "disks": disk_counters(),
        "memory": memory(),
        "temperature": temperature(),
        "storage": storage(),
        "load": list(os.getloadavg()),
        "cores": os.cpu_count() or 1,
        "uptime": int(float(Path("/proc/uptime").read_text().split()[0])),
        "gpus": gpus(),
    }


if __name__ == "__main__":
    print(json.dumps(snapshot(), allow_nan=False))
