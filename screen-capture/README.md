# Screen Capture

Standalone Quickshell application for wlroots Wayland desktops. This is additive:
the existing bar capture menu, helpers, selector, and shortcuts are unchanged.

## Launch

The Linux Home Manager profile imports `screen-capture.nix`. After applying it,
open **Screen Capture** from the application launcher or run `screen-capture`.
Launching again reopens the existing application's menu.

- **1**: screenshot all screens (PNG, also copied to the clipboard)
- **2**: screenshot a region (drag to select; release to capture)
- **3**: record the screen selected in the output dropdown
- **4**: record a region (drag, move/resize, then Enter or Record)
- **Esc**: dismiss the menu or cancel selection

Reopen the app while recording to see the timer and Stop button. Closing the menu
does not stop recording. Recordings include system playback audio, not the mic.
Files go to `$XDG_PICTURES_DIR/Screenshots` and `$XDG_VIDEOS_DIR/Recordings`,
falling back to `~/Pictures` and `~/Videos`.

## Ownership and lifecycle

`config/` owns the menu, region editor, recording outline, and capture state.
The region components and capture adapter were initially copied from the bar;
there are no imports or IPC calls into the bar's configuration.

`scripts/` owns capture operations. The `screen-capture-record-{full,region}`
systemd user units keep recording independently of UI reloads. These units,
runtime files, helper commands, config directory, and overlay namespace are
separate from the legacy bar implementation.

## Control surface (not connected to the bar yet)

```sh
quickshell --path "$HOME/.config/screen-capture" ipc call capture openMenu
quickshell --path "$HOME/.config/screen-capture" ipc call capture status
quickshell --path "$HOME/.config/screen-capture" ipc call capture stop
screen-capture-record status --json
screen-capture-record stop
```

Use `$XDG_CONFIG_HOME/screen-capture` instead when XDG_CONFIG_HOME is set.
The application status snapshot includes `recording`, `mode`, `startedAtMs`, and
`geometry`. The helper status query also works without the application running.

Push events / a D-Bus interface and bar integration are deferred to the next
step. This version provides command/query IPC only. Notifications are not
implemented.

## Manual validation

Validated in an Agent Workspace Linux private X11 desktop with a nested Sway
Wayland compositor (the native Hyprland workspace failed to initialize its output
with the installed compositor version). All capture operations target that
private Wayland display.

Checked screenshot-all, screenshot-region, region movement/resizing, full-screen
and region recording, reopening the menu, and stopping via the application's
Stop button. Private workspace services need access to the user systemd manager
and PulseAudio socket; those were wired only in the temporary test environment,
not in this module.

Evidence for this session: `/tmp/screen-capture-evidence/private-workflow-passed.mp4`.
