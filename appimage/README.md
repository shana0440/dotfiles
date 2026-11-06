# AppImage integration and scaling

Put AppImages directly in `~/Applications`. A user service creates launcher entries
in `~/.local/share/applications` and copies their embedded icons when available.
New, changed, and deleted files are noticed automatically, usually within 30 seconds.
Subdirectories and symlinks are ignored. Download temporary files (such as `.part`)
are ignored, and files must be idle for at least two seconds before extraction.

The integrator extracts metadata without starting the downloaded application and
never imports its embedded `Exec` command. Only launch AppImages you trust: apps
run with your user permissions. Generated entries always use our configured runner.
The AppImage need not be executable.

Apply with `make home`. For an immediate refresh:

```sh
appimage-integrate
```

Diagnostics:

```sh
systemctl --user status appimage-integrate.path appimage-integrate.timer
journalctl --user -u appimage-integrate.service
```

Removing an AppImage removes its managed launcher entry and icon. Existing unrelated
launcher entries are left alone. Use one version of each app in the directory to
avoid duplicate names. HinaCode's old hard-coded Downloads launcher is replaced by
this integration.

Run the unit tests with `python3 -m unittest discover -s appimage -p 'test_*.py'`.

## Scaling

`package.nix` customizes `appimage-run` for all AppImages:

- Electron images default to `--force-device-scale-factor=1` (an explicit flag overrides it).
- Qt and GTK images receive default `QT_SCALE_FACTOR=1` and `GDK_DPI_SCALE=1` settings. Toolkit support varies; this cannot guarantee identical scaling for every AppImage.
- Non-Electron images do not receive Chromium-specific command-line options.

`make home` installs the runner and registers it as the file manager's AppImage handler. `make nixos` also updates the binfmt interpreter for direct execution of executable AppImages. Files executed directly still require `chmod +x`; opening them through the runner does not.

Fully quit an app before testing a new scale: single-instance apps can redirect subsequent launches to an existing process, even when that process is on another display.
