# Screen Capture

Home Manager module (`screen-capture.nix`) that installs the screenshot and
screen-recording commands for wlroots/Hyprland. It has no UI: the capture
toolbar, selectors and recording indicator live in the Quickshell bar
(`quickshell/config/Capture`, see its README), which calls these commands, the
same way the wallpaper picker calls `wallpaper-set`. All dependencies are
declared in `screen-capture.nix`.

## Commands

```sh
screen-capture-screenshot full               # all outputs, PNG + clipboard
screen-capture-screenshot region [GEOMETRY]  # "X,Y WxH"; slurp if omitted

screen-capture-record full OUTPUT            # e.g. DP-1
screen-capture-record region [OUTPUT GEOMETRY]  # slurp if omitted
screen-capture-record window IDENTIFIER      # Hyprland stableId (hex)
screen-capture-record stop
screen-capture-record status [--json]        # {"mode","startedAtSeconds","geometry","window"}

screen-capture-snapshot freeze SCREENS_JSON  # window list + per-window frames
screen-capture-snapshot save-screens DIR FRAMES_JSON [GEOMETRY]
screen-capture-snapshot save-window DIR IDENTIFIER
screen-capture-snapshot cleanup DIR

screen-capture-notify {screenshot|recording} FILE
```

Commands that save a file print its path on stdout once it is written.

Files go to `$XDG_PICTURES_DIR/Screenshots` and `$XDG_VIDEOS_DIR/Recordings`,
falling back to `~/Pictures` and `~/Videos`.

## Screenshots

`screen-capture-screenshot` captures the live desktop with grim. The Quickshell
UI instead saves from its frozen frame through `screen-capture-snapshot`: the
UI grabs each output's frozen screencopy into a private temporary PPM,
`save-screens` composes the outputs (highest scale wins, like grim), crops a
region, writes the PNG and copies it to the clipboard. Pillow is loaded only at
save time. `freeze` lists Hyprland's visible windows (geometry, stacking) and
exports each one's native toplevel frame, so window screenshots contain only
that window. Temporary frames live in private `screen-capture-frame-*`
directories under `$XDG_RUNTIME_DIR` and are removed by `cleanup`.

## Recording

`screen-capture-record` starts the recorder as a transient systemd user unit,
`screen-capture-record-{full,region,window}.service`, so recordings survive
Quickshell reloads. Only one recording runs at a time. Full and region
recordings use wf-recorder; window recording (`screen-capture-window-record`)
captures the Hyprland toplevel at 30 fps with software encoding, keeps its
starting canvas size (letterboxing on resize) and ends when the window closes or
becomes unavailable. Recordings include system playback audio, not the mic.
Stopping sends SIGINT so the MP4 is finalized.

`status` works without any UI running; the start time is the session file's
mtime. When a recording starts or is stopped through `screen-capture-record`, it
pings Quickshell (`quickshell ipc call screenCapture changed`, best effort) so
the bar updates immediately.

## Notifications

Successful screenshots and completed recordings send freedesktop notifications
with the file path and an image preview; recordings get a thumbnail under
`$XDG_CACHE_HOME/screen-capture/previews`. The recording completion hook
(`screen-capture-recording-finished`, the unit's `ExecStopPost`) notifies even
with no UI running and skips failed recordings. Delivery is best effort and
never prevents saving or clipboard delivery.
