# Agent workspace (desktop Linux)

Home Manager installs `agent-workspace-linux` 0.6.3 through `home.nix`:

```sh
make home-linux
agent-workspace-linux doctor
```

The package pins the upstream release binary and checks its hash. Upstream needs
GLIBC_2.43, newer than the host package set, so `package.nix` pins an isolated
Nixpkgs runtime for the binary. This does not upgrade host libraries. Its wrapper
provides the X11 and native-backend commands on PATH. No workspace or MCP server
starts automatically; macOS and WSL profiles are unchanged.

## Start a private X11 desktop

```sh
agent-workspace-linux workspace start --ack-hidden-workspace \
  --id demo --session x11 --width 1280 --height 800 --purpose "Desktop testing"
agent-workspace-linux workspace launch --id demo --name terminal -- xterm
agent-workspace-linux viewer --id demo
```

Control it without sending input to your host desktop:

```sh
agent-workspace-linux workspace type --id demo 'printf "hello from the workspace\n"'
agent-workspace-linux workspace key --id demo Return
agent-workspace-linux workspace screenshot --id demo --output /tmp/workspace.png
agent-workspace-linux workspace stop --id demo
```

Input text and keys are positional arguments, not `--text` or `--key` options.
The viewer appears on the display from which it is launched. Workspace apps use
private display sockets, but still run as your user with access to your files and
network: this is **not a security sandbox**. Viewer Pause did not block direct
CLI input in validation; do not rely on it as a CLI kill switch.

## Validation on this machine

Verified the installed package on x86_64 Linux with real desktops:

- X11 workspace creation, app launch, keyboard input, and screenshot capture.
- JavaScript execution and editing/saving a file in Neovim.
- Viewer rendering on a second private X11 desktop, without opening a host window.
- Closing the app and stopping both workspaces; their daemon/display processes exited.

Recording (33 seconds, 1280×920, 15 fps):

`~/Videos/AgentWorkspaces/agent-workspace-nix-validation-20261102-082610.mp4`

The recording shows the private viewer from stopped state through workspace
startup, terminal use, code execution, editor save, and shutdown. It also labels
the native-backend limitations. This recording is local evidence, not a file
tracked in Git. Native ARM support is packaged but has not been runtime-tested.

## Quickshell limitations

**The current Quickshell configuration is not working in the workspace yet.**

- **X11:** Quickshell launches, but the real config fails to create its Wayland
  layer-shell properties and does not render the bar correctly. X11 success is
  not proof of Quickshell support.
- **Hyprland:** private compositor startup reaches headless-output setup, then
  times out. Its logs show NVIDIA GBM allocation failures; the output remains
  0×0. This machine exposes only an NVIDIA render node. The upstream backend
  targets Hyprland 0.53; the host uses 0.55.4 and our shell uses Lua dispatches,
  so IPC compatibility also needs validation after resolving rendering.
- **KWin:** the private compositor starts, but the required fake-input v6
  protocol is not advertised to the agent. The workspace refuses to become ready.
  The authorization/packaging cause is not resolved; security checks were not disabled.

The host Quickshell was not restarted or modified during testing. Only the
explicitly launched private Quickshell instance was stopped. No NAS access or
worktree automation was configured.
