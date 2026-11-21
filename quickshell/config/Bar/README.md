# Dashboard

Tap `Super` to open the dashboard. `Page Down` / `Page Up` switch tabs,
`Tab` / `Shift+Tab` move between the buttons of the current tab, and `Enter` or
`Space` presses one. A notification that arrives while it is open pops up
when it closes.

- **Home:** calendar and the weather from [wttr.in](https://wttr.in), located
  by your public IP. The weather pill left of the bar's clock shows details on
  hover and opens this tab on click; it hides while offline.
- **Settings:** output and input volume, Wi-Fi, Bluetooth, the
  dark/transparent theme, Do Not Disturb, and the input method. Click a tile to
  toggle it, or its `>` to pick an audio device, join a Wi-Fi network, manage
  Bluetooth devices, or switch input method. Do Not Disturb keeps notifications
  in the list without popping them up, except urgent ones.
- **Network:** connection status.
- **Usage:** Claude and Codex subscription limits, also available as
  `agent-usage`. It reads the logins saved by Pi, Claude Code, or Codex CLI
  without refreshing them, so those tools stay signed in.
  `agent-usage reset-codex [CREDIT_ID]` redeems an earned Codex limit reset.
- **Pomodoro:** 25-minute focus sessions with 5-minute breaks and a 15-minute
  break after every fourth, with a notification at the end of each phase.
  `quickshell ipc call pomodoro toggle` starts or pauses it.

## Search

With the dashboard open, start typing to search it. Only matching tabs stay in
the sidebar, and the best match opens: `wifi` jumps to the settings tab. On the
usage tab, `claude` or `codex` shows only that card. `Page Down` / `Page Up`
step through the matches, `Enter` keeps the current tab, and `Esc` clears the
search.

Each tab matches its name and these keywords (`tabList` in `Dashboard.qml`):

| Tab | Keywords |
|---|---|
| Home | calendar, date, weather |
| Now playing | media, music, song, track, player |
| Notifications | alerts, messages |
| Network | ethernet, internet, connections, ip, speed |
| Settings | volume, sound, speaker, headphones, microphone, mic, output, input, wifi, wi-fi, wlan, ssid, bluetooth, bt, pair, devices, theme, dark, transparent, do not disturb, dnd, quiet, input method, keyboard, language, ime |
| System | cpu, gpu, memory, ram, vram, storage, disk |
| Usage | claude, codex, agent, limit, quota |
| Pomodoro | timer, focus, break |
| Power | shutdown, power off, restart, reboot, lock, log out, logout |

## Status island

The island at the right end of the bar holds the speaker and, when apps run in
the background with a tray icon, a layers button. The island left of it lists
open windows.

Scroll on the speaker to change the volume. Click it to open the sound panel:
the output and input volume, with `v` to pick each device.

Click the layers button to expand the island with the background apps. Click
it again, or click anywhere outside the island, to collapse it.
Click a background app to open it, middle-click for its secondary action, and
right-click for its menu. In the menu, `Left` leaves a submenu and `Esc`
closes it.
