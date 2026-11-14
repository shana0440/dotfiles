# iPhone webcam

Use an iPhone as a webcam through OBS's virtual camera. `iphone-webcam.nix`
installs OBS and the `iphone-webcam` command.

Apply with `make nixos`, then reboot once. The virtual camera is `/dev/video1`,
named **OBS Cam**; nothing else may use that device number.

## Use

```sh
iphone-webcam
```

1. Scan the QR in the terminal with the iPhone Camera app (widen the terminal
   to at least 50 columns if it wraps).
2. Open it in Safari, allow camera access, pick a camera, tap **Start**.
3. In OBS, click **Start Virtual Camera**; select **OBS Cam** in your meeting app.
4. When done, press **Ctrl+C** in the terminal; OBS closes too.

Keep Safari in the foreground and the phone unlocked. Video only; use your
usual microphone. The stream goes through VDO.Ninja and may use internet relays.

The QR contains reusable stream credentials; keep it private. To reset them,
delete `~/.config/iphone-webcam/`. Your normal OBS settings are not touched.
