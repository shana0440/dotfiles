# Eagle on Linux (experimental)

Eagle has no native Linux release. This package wraps the official Windows
**4.0 Build 23** installer with Wine 11 and Microsoft .NET Framework 4.8.
It is enabled by `applications.nix` on x86_64 desktop Linux only.

Run `eagle` or choose **Eagle** in the application launcher after `make home`.
To build/run just this app, including untracked local package files:

```sh
nix build "path:$PWD#eagle"
nix run "path:$PWD#eagle"
```

Nix pins the Eagle installer with a SHA-256 hash and supplies Wine/Winetricks.
The first launch downloads .NET and Microsoft core fonts through Winetricks and
installs them and Eagle into a writable, app-specific Wine prefix. This setup takes several minutes,
requires internet access and a graphical display, and is not a pure Nix build.
Eagle is proprietary and requires a license after its trial.

## Data and configuration

- Wine prefix: `${XDG_DATA_HOME:-$HOME/.local/share}/eagle/wine`
- Override prefix for testing: `EAGLE_WINEPREFIX=/absolute/path eagle`
- Windows executable inside the prefix: `drive_c/Eagle/Eagle.exe`
- Linux files are available as `Z:\\` in Eagle's Windows file dialogs.
- Libraries are stored wherever you choose; back them up separately.

The launcher disables GPU acceleration for Wine/headless compatibility, installs
Windows core fonts, and enables RGB font smoothing. Existing prefixes receive
the font setup once on their next launch; close Eagle before upgrading.

A short-lived X11 helper unmaps Eagle's fixed-size, zero-opacity background
window, which can otherwise appear as an unclosable white box under Wine. It
matches the launched process, transparency, fixed size hints, and non-focusable
WM hints; it never closes the window or hides the main UI. Do not match
skip-taskbar: Hyprland clears that flag, unlike the headless Openbox session.

`hyprland/hyprland.lua` disables compositor-side XWayland bitmap scaling.
The launcher detects the focused Hyprland monitor's scale and passes it to
Electron, so Eagle renders at native resolution on a 150% monitor. This Hyprland
setting affects **all XWayland apps**; other apps may need their own HiDPI setup.

### Native file manager

**Open in Explorer** (`Ctrl+Enter`) opens the item's folder in your Linux file
manager (Thunar here), rather than Wine Explorer. After updating with `make home`,
fully quit and relaunch Eagle to enable it.

The launcher installs a small Explorer adapter only in Eagle's private prefix.
It translates Windows paths using Wine's drive mappings and calls the standard
`org.freedesktop.FileManager1` interface, falling back to `xdg-open`. File requests
select the file when supported; Eagle itself currently requests its containing
folder. Wine's desktop startup is forwarded to the original Explorer. Eagle's
application files, Windows file-selection dialogs, and other prefixes are unchanged.

For large NAS libraries, Wine can repeatedly enumerate every entry while looking
for a missing `desktop.ini` (including case-insensitive filename fallbacks), before
it even launches the adapter. On the real desktop, a 27,836-entry `images/`
directory made a Windows reveal probe take 37 seconds. Adding a minimal
`<library>.library/images/desktop.ini` containing `[.ShellClassInfo]` reduced the
same probe to 1.4 seconds; Eagle's shortcut reached the adapter in 0.8 seconds.
Do not overwrite an existing `desktop.ini`. This is a per-library workaround,
not something the launcher automatically writes into users' libraries.

Wine prefixes isolate app configuration, **not filesystem access**.

## Headless test

Use an agent-workspace X11 desktop (no viewer required):

```sh
agent-workspace-linux workspace start --id eagle-test --ack-hidden-workspace \
  --purpose 'Test Eagle under Wine' --width 1440 --height 1000
agent-workspace-linux workspace launch --id eagle-test --name eagle -- eagle
agent-workspace-linux workspace screenshot --id eagle-test --output /tmp/eagle.png
```

Verified with native .NET 4.8: clean-prefix automatic setup, onboarding,
library creation, PNG folder import, thumbnail generation, and image preview. Wine Mono alone opens the UI but fails Eagle's
C# integration and library creation. Re-tested the normal profile after adding
core fonts: UI text is visibly smoother and the large white helper is hidden.
Also verified directly on the real Hyprland desktop at 150% scale: automatic
helper hiding after a fresh launch, native-resolution text, and one main Eagle
window.
Native reveal was tested in a separate, copied prefix with a disposable library:
Eagle's **Open in Explorer** menu opens the correct item directory in Thunar.
Quoted `/select,` paths with spaces and Unicode were also verified through Wine.
Helper unit tests: `python3 -B eagle/test-native-reveal.py`.

A small Wine tray host and rendering warnings can remain, including a failed
online-download helper request. Browser integration,
plugins, video/PSD/RAW previews and other advanced features are not verified.
Avoid running Eagle in multiple prefixes simultaneously: its local server uses
fixed ports. This is an unsupported compatibility setup, not a
native or officially supported Linux port.
