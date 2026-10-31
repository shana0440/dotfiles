# PipeWire playback listener

`quickshell/quickshell.nix` installs PipeWire's user-session tools and packages
this Quickshell-specific helper as `pipewire-playback-monitor`. The daemon remains
configured in `nixos/configuration.nix`; no privileged service or extra permissions
are needed.

The helper subscribes to `pw-dump --monitor` and emits a JSON line only when
playback changes:

```json
{"playing": true}
```

A running `Stream/Output/Audio` node counts as playback. Microphones, monitor
capture streams (including CAVA), and sink/source devices do not.
Idle, suspended, errored, and removed output streams do not count.

Quickshell starts/stops the helper with `Services/Media.qml`. MPRIS still supplies
metadata and controls, and CAVA provides the visualizer's frequency bands, but
neither decides the playing state. There is no playback polling or silence
hold timer. The helper waits one second before reconnecting only if its
PipeWire connection exits.

A running stream may contain silence or be muted: this reports stream state,
not whether a human can hear sound.

Run tests with:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s quickshell/pipewire -v
```
