# Agent workspace (desktop Linux)

Home Manager installs `agent-workspace-linux` 0.6.3 and
`agent-workspace-quickshell` through `home.nix`:

```sh
make home-linux
agent-workspace-linux doctor
```

The package pins the upstream release binary and checks its hash. Upstream needs
GLIBC_2.43, newer than the host package set, so `package.nix` pins an isolated
Nixpkgs runtime for the binary. This does not upgrade host libraries. Its wrapper
provides the X11 and native-backend commands on PATH. No workspace or MCP server
starts automatically; macOS and WSL profiles are unchanged.

## Private Hyprland with Quickshell

```sh
agent-workspace-linux workspace start --ack-hidden-workspace \
  --id demo --session hyprland --width 1280 --height 800 --purpose "Quickshell testing"
agent-workspace-linux workspace launch --id demo --name shell -- agent-workspace-quickshell
agent-workspace-linux workspace launch --id demo --name terminal -- kitty
agent-workspace-linux viewer --id demo
```

Control it without sending input to the host desktop:

```sh
agent-workspace-linux workspace type --id demo 'printf "hello from the workspace\n"'
agent-workspace-linux workspace key --id demo Return
agent-workspace-linux workspace screenshot --id demo --output /tmp/workspace.png
agent-workspace-linux workspace stop --id demo
```

Text and keys are positional arguments, not `--text` or `--key` options. Click the
terminal to restore focus after dismissing a menu if typing does not reach it.
Prefer native Wayland applications: text injection into XWayland xterm produced
incorrect characters in the private Hyprland session during validation.

### Workspace-only compatibility

- **Rendering:** Aquamarine's headless fallback guessed implicit/linear buffer
  support instead of using the parent Wayland compositor's supported modifiers.
  NVIDIA allocation failed and the output stayed at 0×0. The local patch reuses
  parent formats. `replaceDependency` substitutes the patched library only into
  the workspace Hyprland closure; the running host compositor is unchanged.
- **IPC:** the launcher derives the signature from the workspace's published IPC
  socket, never from the host environment. A private short-lived runtime symlink
  avoids Qt's Unix socket path limit. It is removed when the launcher exits.
- **Configuration:** the launcher uses a Nix-built snapshot of this checkout's
  real Quickshell config, with a workspace-only patch supporting both legacy and
  Lua workspace dispatches. The upstream runtime generates a legacy Hyprland
  config. The host's live QML files are not changed. Run `make home-linux` after
  editing QML to rebuild the workspace snapshot.
- **Config lookup:** the launcher gives Quickshell a private `XDG_CONFIG_HOME`,
  keeping its IPC clients and screenshot notifications separate from the host.
  It refuses to run outside a workspace with a private Hyprland IPC socket.

## Private X11 desktop

X11 is also available for apps that do not require Wayland layer-shell:

```sh
agent-workspace-linux workspace start --ack-hidden-workspace \
  --id x11-demo --session x11 --width 1280 --height 800 --purpose "Desktop testing"
agent-workspace-linux workspace launch --id x11-demo --name terminal -- xterm
agent-workspace-linux viewer --id x11-demo
agent-workspace-linux workspace stop --id x11-demo
```

## Validation and recordings

Verified on this NVIDIA-only x86_64 Linux machine using real desktop interactions:

- Private Hyprland startup and 1280×800 rendering.
- Quickshell bar rendering, workspace buttons switching away from and back to a
  native terminal, capture-menu opening, and Escape dismissal.
- Native Kitty keyboard input and JavaScript execution.
- Screenshot creation and its notification through the real capture menu.
- X11 app launch, code execution, Neovim editing/saving, and viewer rendering on
  another private X11 display.
- Workspace shutdown, process cleanup, and removal of temporary runtime aliases.

Local recordings, not Git-tracked:

| Recording | Location |
| --- | --- |
| Hyprland + Quickshell, 36 seconds, 1280×800 at 15 fps | `~/Videos/AgentWorkspaces/hyprland-quickshell-20261102-085503.mp4` |
| Initial X11 validation, 33 seconds, 1280×920 at 15 fps | `~/Videos/AgentWorkspaces/agent-workspace-nix-validation-20261102-082610.mp4` |

Frames decoded from both recordings were inspected. The earlier X11 recording
labels the native rendering failure that the Aquamarine patch subsequently fixed.
Native ARM support is packaged but has not been runtime-tested.

## Remaining limitations

- Audio/PipeWire, Wi-Fi, Fcitx/IME, and systemd-based recording-service integration
  have not been wired into the private bus. Missing PipeWire/portal warnings are
  expected. The Quickshell validation does not claim these integrations work.
- Standalone KWin still refuses startup because fake-input v6 is not advertised
  to the agent. Its authorization/packaging cause is unresolved. No compositor
  permission checks were disabled to obtain the Hyprland results.
- Viewer Pause did not block direct CLI input in validation; do not rely on it as
  a CLI kill switch.
- Apps still run as your user and can access your files/network: this is **not a
  security sandbox**. The viewer opens on the display from which it is launched.

The host Quickshell was not restarted or modified. No NAS access or worktree
automation was configured.
