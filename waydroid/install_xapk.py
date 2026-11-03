"""Install APK-only XAPK bundles, starting the user's Waydroid session if needed."""

import argparse
from dataclasses import dataclass
import errno
import ipaddress
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import socket
import stat
import subprocess
import sys
import tempfile
import time
import traceback
import zipfile

MAX_APK_BYTES = 2 * 1024**3
MAX_MANIFEST_BYTES = 1024**2


@dataclass(frozen=True)
class Bundle:
    name: str
    package: str
    apks: tuple[Path, ...]


def manifest_metadata(archive):
    entry = archive.getinfo("manifest.json")
    if entry.file_size > MAX_MANIFEST_BYTES:
        raise ValueError("XAPK manifest is too large")
    manifest = json.loads(archive.read(entry))
    if not isinstance(manifest, dict) or manifest.get("xapk_version") != 2:
        raise ValueError("Only version-2 XAPK split bundles are supported")
    package = manifest.get("package_name")
    if not isinstance(package, str) or not re.fullmatch(r"[A-Za-z]\w*(?:\.[A-Za-z]\w*)+", package, re.ASCII):
        raise ValueError("Invalid Android package name in XAPK manifest")
    name = manifest.get("name", package)
    if not isinstance(name, str) or not name.strip():
        raise ValueError("Invalid app name in XAPK manifest")
    if manifest.get("expansions") or any(item.filename.lower().endswith(".obb") for item in archive.infolist()):
        raise ValueError("This bundle includes OBB game data; OBB installation is not supported")
    return manifest, name, package


def apk_members(archive, manifest):
    splits = manifest.get("split_apks")
    if not isinstance(splits, list) or not 1 <= len(splits) <= 256:
        raise ValueError("XAPK must declare between 1 and 256 APK splits")
    names = []
    for split in splits:
        name = split.get("file") if isinstance(split, dict) else None
        if not isinstance(name, str):
            raise ValueError("Invalid split entry in XAPK manifest")
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or "\\" in name or path.suffix.lower() != ".apk":
            raise ValueError("Unsafe or non-APK split path in XAPK manifest")
        names.append(name)
    if len(set(names)) != len(names):
        raise ValueError("XAPK declares duplicate APK splits")
    members = tuple(archive.getinfo(name) for name in names)
    if any(stat.S_ISLNK(member.external_attr >> 16) for member in members):
        raise ValueError("APK members must be regular files, not symlinks")
    if sum(member.file_size for member in members) > MAX_APK_BYTES:
        raise ValueError("APK payload exceeds the 2 GiB extraction limit")
    return members


def unpack_bundle(source, destination):
    with zipfile.ZipFile(source) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("XAPK contains duplicate archive entries")
        manifest, name, package = manifest_metadata(archive)
        members = apk_members(archive, manifest)
        needed = sum(member.file_size for member in members) + 128 * 1024**2
        if shutil.disk_usage(destination).free < needed:
            raise ValueError("Not enough temporary disk space to extract this XAPK")
        paths = []
        for index, member in enumerate(members):
            # Never use untrusted archive paths as output paths.
            target = destination / f"split-{index}.apk"
            with archive.open(member) as incoming, target.open("xb") as outgoing:
                shutil.copyfileobj(incoming, outgoing)
            paths.append(target)
        return Bundle(name, package, tuple(paths))


def waydroid_endpoint(leases, now):
    """Return the one container endpoint, or None while DHCP is still starting."""
    addresses = set()
    for line in leases.splitlines():
        if not line.strip():
            continue
        fields = line.split()
        if len(fields) != 5:
            raise ValueError("Invalid Waydroid DHCP lease record")
        expires = int(fields[0])
        address = ipaddress.IPv4Address(fields[2])
        if expires == 0 or expires > now:
            addresses.add(address)
    if not addresses:
        return None
    if len(addresses) != 1:
        raise ValueError("Exactly one active Waydroid container address is required")
    return f"{addresses.pop()}:5555"


def dialog(kind, text):
    command = ["zenity", f"--{kind}", "--no-markup", "--width=480",
               "--title=Install XAPK in Waydroid", "--text", text]
    if kind == "question":
        command += ["--ok-label=Install", "--cancel-label=Cancel", "--default-cancel"]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.stderr:
        sys.stderr.write(result.stderr)
    # Zenity documents exit 1 as cancel/dismiss, even if GTK emitted warnings.
    # Confirmation callers return nonzero, preserving failure if the GUI could not open.
    if result.returncode == 1:
        return False
    result.check_returncode()
    return True


def ensure_session():
    import dbus

    manager = dbus.Interface(
        dbus.SystemBus().get_object("id.waydro.Container", "/ContainerManager"),
        "id.waydro.ContainerManager",
    )
    session = manager.GetSession()
    if session.get("user_id") not in (None, "", str(os.getuid())):
        raise RuntimeError("Waydroid belongs to another user; refusing to control that session")
    if session.get("state") != "RUNNING":
        starter = subprocess.Popen(["waydroid", "show-full-ui"], start_new_session=True)
        deadline = time.monotonic() + 60
        while session.get("state") != "RUNNING":
            code = starter.poll()
            if code not in (None, 0):
                raise subprocess.CalledProcessError(code, starter.args)
            if time.monotonic() >= deadline:
                raise TimeoutError("Waydroid did not start within 60 seconds")
            time.sleep(0.5)
            session = manager.GetSession()
    if session.get("user_id") != str(os.getuid()):
        raise RuntimeError("Waydroid session ownership could not be verified")


def wait_for_adb():
    deadline = time.monotonic() + 60
    leases = Path("/var/lib/misc/dnsmasq.waydroid0.leases")
    while time.monotonic() < deadline:
        text = leases.read_text() if leases.is_file() else ""
        endpoint = waydroid_endpoint(text, time.time())
        if endpoint is not None:
            address = endpoint.split(":")[0]
            route = subprocess.run(["ip", "-j", "route", "get", address],
                                   capture_output=True, text=True, check=True, timeout=10)
            routes = json.loads(route.stdout)
            if len(routes) != 1 or routes[0].get("dev") != "waydroid0":
                raise RuntimeError("The Waydroid bridge is not ready; refusing another network route")
            try:
                with socket.create_connection((address, 5555), timeout=1):
                    return endpoint
            except OSError as error:
                # At this startup boundary only, refusal/unreachability/timeouts mean
                # adbd is still booting. Bound retries; propagate every other error.
                if not isinstance(error, TimeoutError) and error.errno not in (
                    errno.ECONNREFUSED, errno.EHOSTUNREACH, errno.ETIMEDOUT,
                ):
                    raise
        time.sleep(0.5)
    raise TimeoutError("Waydroid ADB did not become ready within 60 seconds")


def install_apks(bundle):
    progress = subprocess.Popen([
        "zenity", "--progress", "--pulsate", "--no-cancel",
        "--title=Installing XAPK in Waydroid",
        "--text=Starting Waydroid and installing APK splits together.\nIf Android asks, allow USB debugging from this computer.",
    ], stdin=subprocess.PIPE)
    try:
        ensure_session()
        endpoint = wait_for_adb()
        connection = subprocess.run(["adb", "connect", endpoint], capture_output=True, text=True, timeout=15)
        if connection.returncode:
            devices = subprocess.run(["adb", "devices"], capture_output=True, text=True, check=True, timeout=10)
            # An authorization prompt is expected here, not a failed installation.
            unauthorized = any(line.split() == [endpoint, "unauthorized"] for line in devices.stdout.splitlines())
            if not unauthorized:
                connection.check_returncode()
        command = ["adb", "-s", endpoint]
        subprocess.run(command + ["wait-for-device"], capture_output=True, text=True, check=True, timeout=60)
        subprocess.run(command + ["install-multiple", "-r", *map(str, bundle.apks)],
                       capture_output=True, text=True, check=True, timeout=180)
    finally:
        # Only close the progress process owned by this invocation.
        if progress.poll() is None:
            progress.terminate()
        progress.wait()
        progress.stdin.close()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.bundle.suffix.lower() != ".xapk":
            raise ValueError("Choose an .xapk bundle, not an ordinary ZIP archive")
        with tempfile.TemporaryDirectory(prefix="waydroid-xapk-") as directory:
            bundle = unpack_bundle(args.bundle, Path(directory))
            if not dialog("question", f"Install {bundle.name} ({bundle.package}) in Waydroid?\n\n"
                          f"Source: {args.bundle.name}\nAPK splits: {len(bundle.apks)}\n\n"
                          "Waydroid opens automatically. Existing app data is kept when updating."):
                return 1
            install_apks(bundle)
        dialog("info", f"Installed {bundle.name} in Waydroid.\n\nOpen it from Android's app launcher.")
        return 0
    except Exception as error:
        # GUI entry-point boundary: report the actual error and fail, never fake success.
        # This includes malformed JSON, archive/I/O errors and failed ADB commands.
        traceback.print_exc()
        detail = str(error)
        if isinstance(error, subprocess.CalledProcessError):
            detail += "\n" + (error.stderr or error.stdout or "")
        dialog("error", f"XAPK installation failed.\n\n{detail[:2000]}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
