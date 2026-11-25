---
name: desktop
description: Control the user's Linux desktop (Hyprland and the Quickshell desktop shell). Use when the user asks to do something on their computer, such as switching workspaces, opening apps, changing the wallpaper or theme, notifications, screenshots, timers, volume, Wi-Fi, or Bluetooth, or asks what the desktop can do.
---

# Desktop

## Learn what it offers

- Features: `~/dotfiles/README.md` and the documents it links to.
- Shell commands: run `quickshell ipc show`. Use these targets:
  `dashboard`, `overview`, `wallpaper`, `theme`, `notifications`, `pomodoro`,
  `capture`, `screenshotEditor`, `lock`, `dock` (open apps; `activate <appId>`
  focuses or cycles one), `status` (background tray apps, sound view), `sound`
  (output, input and app volume, audio devices), `windowSwitcher` (the
  Super+Tab window list), `usage` (the dashboard's
  cached Claude and Codex limits; `refresh` checks now). Each has a `state` function
  that reads it. Leave the rest to the shell itself.

## Act

| To | Run |
| --- | --- |
| Use the shell | `quickshell ipc call <target> <function> [args]`, e.g. `quickshell ipc call dashboard open pomodoro` |
| See windows, workspaces, monitors | `hyprctl -j clients`, `hyprctl -j workspaces`, `hyprctl -j monitors` |
| Switch workspace | `hyprctl dispatch 'hl.dsp.focus({ workspace = 2 })'` |
| Focus, move or close a window | `hyprctl dispatch 'hl.dsp.focus({ window = "class:kitty" })'`, `hyprctl dispatch 'hl.dsp.window.move({ workspace = 3, window = "class:kitty" })'`, `hyprctl dispatch 'hl.dsp.window.close({ window = "class:kitty" })'` |
| Minimize or restore a window | `hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "class:kitty" })'`; restore by moving it to a numbered workspace |
| Open an app | `hyprctl dispatch 'hl.dsp.exec_cmd("kitty")'` |
| Set the wallpaper | `wallpaper-set <image-or-video>` (files live in `~/Pictures/Wallpapers`); `quickshell ipc call wallpaperTransition state` shows the playing video |
| Take a screenshot or record | `screen-capture-screenshot full`, `screen-capture-record full <monitor>`, `screen-capture-record stop` |
| Change the capture toolbar selection | `quickshell ipc call capture open`, then use `capture selectTarget <full\|window\|region>` and `capture selectKind <screenshot\|recording>` with `quickshell ipc call`; read the selection with `capture state` |
| Show the user something | `notify-send '<title>' '<body>'` |
| Turn notification sounds on or off | `quickshell ipc call notifications sound true` or `quickshell ipc call notifications sound false` |
| Use the clipboard | `wl-copy`, `wl-paste` |
| Volume | `quickshell ipc call sound state`, `quickshell ipc call sound setVolume 40`, `quickshell ipc call sound setAppVolume spotify 60` |
| Wi-Fi, Bluetooth | `nmcli`, `bluetoothctl` |
| Agent usage limits | `agent-usage` |
| Install the Media Preview Server plugin in Eagle | `eagle-media-preview-install`; see [Eagle on Linux](../../../eagle/README.md) |
| Apps started in the tray at login | `app-autostart list`; start one again with `app-autostart start <name>` |

`hyprctl dispatch` takes Lua; `hyprland/hyprland.lua` in the dotfiles shows
more `hl.dsp` dispatchers. Act through these commands only. When something has
no command, tell the user it is missing.

## Ask first

- Look things up whenever it helps.
- Act when the user asks for it in the current conversation.
- Confirm with the user before you lock the screen, log out, restart or power
  off, start a recording, or close a window.
- In scheduled and background runs, report with `notify-send` and leave the
  desktop as it is.
