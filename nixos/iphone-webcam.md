# iPhone webcam

`iphone-webcam.nix` installs OBS with browser support, configures v4l2loopback,
and provides an `iphone-webcam` command and terminal-based app-launcher entry.

## Apply

From the repository root:

```sh
make nixos
```

Reboot after first enabling the module or changing the kernel. The virtual
camera uses the NixOS default `/dev/video1`, named **OBS Cam**. Another camera
occupying that device number must be resolved before using it.

## Start and stop

```sh
iphone-webcam
```

1. Scan the QR displayed in the terminal with your iPhone Camera app.
2. Open in Safari, allow camera access, select a camera, and tap **Start**.
3. OBS automatically receives the feed in the **iPhone Webcam** scene.
4. Click **Start Virtual Camera** and select **OBS Cam** in your meeting app.
5. When finished, press **Ctrl+C** in the launcher terminal. OBS closes too.

The launcher stays in the foreground for the entire meeting. Closing its
terminal or sending SIGTERM also stops its OBS instance. Closing OBS ends the
launcher. Do not use `kill -9`: SIGKILL cannot be handled for cleanup.
No desktop browser is opened. The app-launcher entry opens a terminal instead.
If the QR wraps, widen the terminal (at least 50 columns) and rerun the command.

Keep Safari in the foreground and the phone unlocked. Use your usual microphone:
the virtual camera carries video only. VDO.Ninja may use internet signaling or
relays, even on the same Wi-Fi.

## Configuration and privacy

The QR contains a random reusable stream ID and password. OBS receives the
matching viewer link automatically. Keep the QR private; anyone with it has
stream credentials. Existing OBS settings and scenes are untouched; the helper
uses a dedicated setup under `${XDG_CONFIG_HOME:-$HOME/.config}/iphone-webcam/`.
A second concurrent launcher is refused. Only the launcher's OBS instance and
its browser helpers are stopped, not unrelated OBS windows.

To reset pairing, stop the launcher, remove its dedicated configuration
directory, and relaunch. This also resets any dedicated OBS customizations.

OBS logs: `${XDG_CACHE_HOME:-$HOME/.cache}/iphone-webcam/obs.log`.
A black preview before the phone starts sharing is expected.

## Validation

Nix build/ShellCheck passed. A private X11 agent workspace test confirmed the
terminal QR renders, the preconfigured Browser source loads, and Ctrl+C stops
OBS. Longer headless runs also encountered a CEF GPU-process crash; a real
phone feed and virtual-camera output remain untested.

Separate lifecycle checks with a stub OBS verified SIGINT, SIGTERM, and SIGHUP
stop the child and duplicate launchers are refused.

Recording: `/tmp/iphone-webcam-lifetime-demo.mp4` (temporary local artifact with
throwaway test credentials, not committed).
