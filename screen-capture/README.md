# Screen Capture

Standalone Quickshell application for wlroots Wayland desktops. It replaces the
bar's former built-in capture menu, selector and helper scripts; the bar only
reflects recording state and offers Stop.

## Launch

The Linux Home Manager profile imports `screen-capture.nix`. After applying it,
open **Screen Capture** from the application launcher or run `screen-capture`.
Launching again reopens the existing application's menu. Hyprland preloads the
hidden UI at session startup with `screen-capture --background`; this does not
show a toolbar or capture a frame. You can also run that command once in an
existing session after applying the configuration.

Launching captures a frozen desktop frame **before** showing a compact, bottom-centered
toolbar and the same dimmed backdrop used for region selection. The applications
themselves keep running; the preview stays at launch time.
Screenshots are saved from that frame, not from the live desktop at confirmation time,
so they never include the toolbar, shading, or selection border.

The toolbar groups screenshot modes, a divider, recording modes, and the action
button without a spacer. The action reads **Capture** for screenshots and
**Record** for recording modes. Choose a mode with the icons or number keys:

- **1**: screenshot all screens (PNG, also copied to the clipboard)
- **2**: screenshot a window
- **3**: screenshot a region
- **4**: record a screen
- **5**: record a window
- **6**: record a region

**Window modes** (Hyprland): point at a window to highlight it, click to lock the
choice, then press Enter/Capture/Record. Window geometry and stacking are frozen
at launch, together with an image of each visible window exported through
Hyprland's native toplevel capture. Window screenshots therefore contain only
that window's content as of launch, never overlapping windows, the dimmed
backdrop, or the toolbar.

Window recording captures the selected toplevel natively at 30 fps (video plus
system audio, no mic). It keeps following that window when it moves or is covered.
If it is resized, the video keeps its starting canvas size and letterboxes. It
finishes if the window closes or becomes unavailable (e.g. minimized or on a
hidden workspace). Window recording uses software encoding and is heavier than
full-screen/region recording on large windows.

For region modes, drag to select and move/resize using the handles. Click
**Capture** / **Record**, or press **Enter**, to confirm. There is no Options menu
or screen picker: full-screen recording uses the toolbar's screen, and selecting
a region on another screen moves the toolbar there. **Esc** dismisses
the toolbar and releases the frozen frame without capturing.

Recording returns to the **live** desktop before the recorder starts. A compact
**Stop + elapsed time** control stays visible automatically until recording ends;
there is no need to reopen the app. It does not grab keyboard focus or block
normal desktop input outside its bounds. Reopening never freezes an ongoing
recording. Recordings include system playback audio, not the mic.
Files go to `$XDG_PICTURES_DIR/Screenshots` and `$XDG_VIDEOS_DIR/Recordings`,
falling back to `~/Pictures` and `~/Videos`.

## Ownership and lifecycle

`config/` owns the menu, region editor, recording outline, and capture state.
The region components and capture adapter were originally copied from the bar,
which no longer contains them. There are no imports or IPC calls between the two
configurations.

The frozen desktop comes from compositor screencopy (Quickshell
`ScreencopyView`, one non-live frame per output) shown directly from GPU
memory, so the toolbar appears without waiting for a file to be written, decoded
and uploaded. In a 3840×2160 nested test the toolbar was ready about 8–10 ms
after the request (software rendering), against roughly 170–235 ms with the
earlier grim-to-file approach.

Screenshots are saved from those same frames: each overlay grabs its
`ScreencopyView` (only that item, never the backdrop or toolbar) at native
resolution into a private temporary PPM, and `scripts/snapshot.py save-screens`
composes the outputs (highest scale wins, like grim), crops regions, writes the
PNG and copies it to the clipboard. Pillow is loaded only at save time.
Hyprland's native window list and per-window frames are prepared by
`snapshot.py freeze` in parallel; window modes show "Loading windows…" for the
few tens of milliseconds until it reports. Temporary frames live in private
directories under `$XDG_RUNTIME_DIR` and are removed on capture, cancel, or
normal UI shutdown.

`scripts/` owns capture operations. The `screen-capture-record-{full,region,window}`
systemd user units keep recording independently of UI reloads. These units,
runtime files, helper commands, config directory, and overlay namespace belong
to this app.

## Control surface and bar integration

```sh
quickshell --path "$HOME/.config/screen-capture" ipc call capture openMenu
quickshell --path "$HOME/.config/screen-capture" ipc call capture status
quickshell --path "$HOME/.config/screen-capture" ipc call capture stop
screen-capture-record status --json
screen-capture-record stop
```

Use `$XDG_CONFIG_HOME/screen-capture` instead when XDG_CONFIG_HOME is set.
The application status snapshot includes `recording`, `mode`, `startedAtMs`, and
`geometry`, plus `preview` to indicate whether a frozen frame is displayed. The
helper status query also works without the application running.

`screen-capture-record` pings the bar (`quickshell ipc call screenCapture changed`)
when a recording starts or is stopped through it, so the bar updates immediately.
The bar (`quickshell/config/Services/Capture.qml`) also polls
`screen-capture-record status --json` once a second as a fallback, e.g. when a
recorded window closing ends a recording on its own. While a recording runs it
shows the elapsed time and a Stop button in the center island, and stops via
`screen-capture-record stop`. The bar has no capture menu or settings island;
launch capture with Super+Shift+S or the application launcher.

There is no D-Bus interface yet, and
notifications are not implemented; the bar's saved-capture notification view
is currently never triggered. The app's own floating Stop control also remains
visible while recording.

## Manual validation

Initial validation used nested Sway in an Agent Workspace Linux private X11
desktop. The mouse-selection regression was then reproduced and fixed on native
Hyprland 0.55.4, nested in a private KWin virtual renderer launched inside Agent
Workspace Linux. All capture operations and input target the private session,
not the user's desktop.

Hyprland routes pointer input through its exclusive layer-surface group when
that group is nonempty. The frozen selector and toolbar both join this group;
shortcuts use application scope so Enter/Escape/number keys still work after a
mouse drag focuses the selector. Recording controls request no keyboard focus.

Checked the toolbar, frozen preview with a running clock, full and region
screenshots from the original frame, live full-screen and region recording,
reopening the toolbar, Stop, cancellation cleanup, and UI restart during recording.
A saved full screenshot was also pixel-compared with its launch frame.
Private workspace services need access to the user systemd manager and PulseAudio
socket; those were wired only in the temporary test environment, not in this module.
Native Hyprland checks covered mouse drawing, moving, and resizing in both region
modes; Enter confirmation after dragging; automatic persistent Stop controls;
and typing into a normal desktop application while recording. The previous
selector configuration was also checked to reproduce the failed drag.
Evidence: `/tmp/screen-capture-pointer-evidence/`.
Multi-monitor / mixed-scale layouts have not been manually validated.

Toolbar/freeze/recording evidence: `/tmp/screen-capture-toolbar-evidence/validated-workflow.mp4`.
Launch backdrop: `/tmp/screen-capture-speed-evidence/launch-backdrop.png`.
Latest grouped toolbar and all four mode/action-label transitions:
`/tmp/screen-capture-layout-evidence/layout-workflow.mp4`.
On the private 1280×800 desktop, three manual snapshot-preparation timings had
medians of 128.5 ms before and 70.9 ms after the raw-frame change (not total launch
time). Background preload, region screenshot saving, and cleanup were also checked.
