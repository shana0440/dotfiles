# Quickshell validation

- When the user requests Agent Workspace Linux testing, that request authorizes
  launching an isolated Quickshell instance there. Do not ask again. Keep its
  D-Bus session isolated and leave the user's desktop instance untouched.
- Otherwise, use the user's already-running Quickshell instance. Do not launch
  another instance or restart it unless the user explicitly asks.
- Validate changes by interacting with the actual desktop and capturing
  screenshots or screen recordings. Inspect the captured evidence yourself.
- Do not add automated tests, offscreen harnesses, fake services, or fixtures.
  Passing scripts, status queries, logs, and syntax checks are not proof that the
  UI works.
- Reproduce the reported workflow from its initial state, including transitions,
  rather than checking only the final state. Do not claim success if a required
  step is missing or fails in the recording.
- Give the user the evidence file path and state any remaining failures honestly.

# Recording a session

`session/lib.sh` starts an isolated copy of the desktop (hidden KWin host,
nested Hyprland, this repo's Quickshell config, optionally a real mei with a
copy of the user's settings) and drives it with a virtual keyboard and mouse.
Write a scenario script for the workflow under review that sources
`session/lib.sh`:

```bash
session_start --mei          # extra arguments: commands the scenario needs, e.g. kitty
record_start
press super+k 1
wait_for 10 has_layer quickshell-phone
shot opened
record_save
```

- Input: `press`, `type_text`, `move`, `click`, `click_at`, `right_click`,
  `drag`, `scroll_up`, `scroll_down`. Waiting: `wait_for`, `click_until` with
  `has_layer`, `lacks_layer`, `has_client`, `lacks_client`, `active_class_is`,
  `active_workspace_is`, `mei_answered`, `brightness`. Inspection: `hypr`,
  `shell_ipc`, `clipboard`, `shot`.
- The screen is 1920x1080 at scale 1. The lock password is `$lock_password`.
- `wait_for` only paces the script; inspect the screenshots and recording
  before reporting.

# Documentation

- When changing a dashboard tab or its search keywords (`tabList` in
  `config/Bar/Dashboard.qml`), update the keyword table under "Dashboard
  search" in the root `README.md` to match.
