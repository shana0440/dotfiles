# Dotfiles

Nix configuration for a Hyprland + Quickshell desktop on NixOS, with the same
shell, Git, Neovim, and tmux setup on macOS and WSL. User settings are managed
by Home Manager (release 26.05); the system by `nixos/`.

The checkout must live at `~/dotfiles`: Git, Neovim, tmux, Kitty, and Hyprland
configs are live links into it, and the NAS service reads its secret from it.

## Before you start: username

The username `kwguo` is hard-coded. To use another name, replace it in:

- `config.nix` (`home.username`)
- `home.nix`, `macos.nix`, `wsl.nix` (`home.homeDirectory`)
- `nixos/user.nix` (`user.name`) and `nixos/configuration.nix` (`networking.hostName`)
- the profile names in `flake.nix` and `Makefile`

Also review `nixos/configuration.nix` for machine choices: time zone, and
`services.nas.enable` (see [`nixos/nas/`](nixos/nas/README.md)).

## Install

- **New NixOS machine (dual boot with Windows):** follow
  [`nixos/INSTALL.md`](nixos/INSTALL.md).
- **Existing system (any OS), Home Manager only, no sudo:** clone to
  `~/dotfiles`, then pick a profile and run:

  ```sh
  export NIX_CONFIG='extra-experimental-features = nix-command flakes'
  nix run 'https://github.com/nix-community/home-manager/archive/refs/heads/release-26.05.tar.gz' -- \
    switch -b backup --flake ~/dotfiles#kwguo-aarch64-darwin
  ```

  | Profile | Platform |
  | --- | --- |
  | `kwguo-x86_64-linux`, `kwguo-aarch64-linux` | Desktop Linux (Hyprland, Kitty, apps) |
  | `kwguo-x86_64-darwin`, `kwguo-aarch64-darwin` | macOS (CLI + Kitty) |
  | `kwguo-x86_64-linux-wsl`, `kwguo-aarch64-linux-wsl` | WSL (CLI only) |

  If `home-manager` is not found afterwards, open a new login session or use
  `~/.nix-profile/bin/home-manager`.
- **Existing NixOS machine:** generate `nixos/hardware-configuration.nix` with
  `nixos-generate-config --show-hardware-config > nixos/hardware-configuration.nix`,
  set the Windows EFI UUID in `nixos/grub.nix` (or remove that entry), then run
  `make nixos` and `make home`.

New files must be `git add`ed before a flake build sees them (no commit needed).

## Day-to-day commands

Run from `~/dotfiles`. Needs GNU Make (`nix-shell -p gnumake --run 'make home'`
if it is missing).

```sh
make home          # Apply Home Manager; detects macOS / Linux / WSL. No sudo.
make nixos         # Rebuild NixOS from nixos/configuration.nix (sudo).
make update        # Update flake.lock (nixpkgs, Home Manager, Zen, Pi-Bolt), then make home.
make nixos-update  # Update the NixOS channel and rebuild.
```

Override the profile with `make home HOME_CONFIG=<profile>`. Never change
`home.stateVersion` or `system.stateVersion` to update packages.

What needs which command:

- Native configs need no rebuild: `git/`, `neovim/config/`, `tmux/.tmux.conf`
  (`tmux source-file ~/.tmux.conf`), `kitty/` (Ctrl+Shift+F5), and
  `hyprland/hyprland.lua` (`hyprctl reload`).
- `.nix` files under the Home Manager profiles: `make home`.
- `nixos/`, and the `nixos` modules of `applications.nix`, `vpn/`, and
  `file-manager/`: `make nixos`.
- Fish is generated from `shell/fish.nix`; do not edit its generated files. The
  login shell is set by NixOS (`make nixos`, then log in again).

The first Neovim launch downloads plugins and Mason language servers (network
required).

## Layout

| Path | Contents |
| --- | --- |
| `flake.nix` | Profiles and pinned inputs |
| `config.nix` | Shared user settings |
| `home.nix` / `macos.nix` / `wsl.nix` | Per-platform module imports |
| `programs.nix`, `shell/`, `git/`, `neovim/`, `tmux/`, `agents/` | Shared CLI tools, Fish, editors, coding agents |
| `applications.nix` | Desktop apps (Home Manager) and Firefox/Steam (NixOS) |
| `hyprland/`, `quickshell/`, `kitty/`, `wallpaper/`, `screen-capture/` | Desktop Linux session |
| `nixos/` | System configuration |
| [`vpn/`](vpn/README.md), [`file-manager/`](file-manager/README.md), [`eagle/`](eagle/README.md), [`nexon/`](nexon/README.md) | Optional apps |
| `agent-workspace/` | Isolated X11 desktops for coding agents |

## Desktop shortcuts

All bindings are in `hyprland/hyprland.lua`. The main ones:

- `Super+Space`: app launcher. `Super+E`: file manager. `Super+Q`: close window.
  `Super+M`: log out.
- `Super+C/V/X/A/Z/F/S/O/L/T/W/R` send `Ctrl+` the same key (macOS-style).
- `Alt+F`: toggle fullscreen. `Ctrl+Up`: workspace overview.
- `Alt+1`…`Alt+0`: workspaces 1–10; add `Shift` to move the focused window.
- `Ctrl+Left` / `Ctrl+Right`: previous / next workspace (overrides apps'
  word navigation).
- `Super+Arrow`: move focus.
- `Super+Shift+S`: screen capture ([details](quickshell/config/Capture/README.md)).
- `Super+Shift+W`: wallpaper picker ([details](wallpaper/README.md)).

### Input methods

Fcitx5 with Mozc (Japanese) and Chewing (Zhuyin). Log out and back in after the
first `make home`.

- `Ctrl+F1` / `Ctrl+F2` / `Ctrl+F3`: English / Mozc / Chewing.
- `Ctrl+Space`: cycle input methods.
- `Super+Ctrl+Space`: toggle Hiragana ↔ Katakana in Mozc.
- Engine list and shortcuts live in `hyprland/hyprland.nix`; other preferences
  in `fcitx5-configtool`.

## Secrets

Secrets are Git-ignored files created from committed `*.example.*` templates:

```sh
install -m 600 path/to/secrets.example.yaml path/to/secrets.yaml
```

`secrets.yaml` and `secrets.json` are ignored everywhere; add other names to
`.gitignore` before use. Modules read them at runtime, so they stay out of the
Nix store.

## Optional services

- **AirPlay receiver:** after `make nixos`, run `uxplay -p` and choose this
  computer under **Screen Mirroring** on an Apple device on the same LAN.
- **iPhone webcam:** see [`nixos/iphone-webcam.md`](nixos/iphone-webcam.md).
- **NAS mount:** see [`nixos/nas/`](nixos/nas/README.md).
- **Agent usage:** the Quickshell dashboard's usage tab shows Claude and Codex
  subscription limits (`agent-usage` on the command line).
