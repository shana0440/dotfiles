# Verification

- Record UI changes in an isolated session (below), with real services, and
  keep the user's running Quickshell as it is.
- Reproduce the workflow from its initial state through every transition.
- Watch the screenshots and recording yourself, and report success only for
  steps they show working. Give the user the file paths and any remaining
  failures.

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

# Documentation

- When changing a dashboard tab or its search keywords (`tabList` in
  `config/Bar/Dashboard.qml`), update the keyword table in
  `config/Bar/README.md` to match.
