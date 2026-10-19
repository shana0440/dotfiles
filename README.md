# User dotfiles

Standalone Home Manager for kwguo on Linux, macOS, and WSL, using release 26.05.

- `applications.nix`: exports `nixos` (Firefox/Steam) and `homeManager` (Discord, Bitwarden, Telegram, Signal, Anki) modules
- `common.nix`: shared user settings and modules
- `home.nix`: desktop Linux profile (common + desktop apps + Kitty + Hyprland)
- `macos.nix`: macOS profile (common + Kitty)
- `wsl.nix`: WSL profile (common CLI tools only)
- `hyprland/`: native Lua configuration, linked on desktop Linux only (not WSL)
- `kitty/`: Kitty package and native configuration on Linux/macOS (not WSL)
- `programs.nix`: portable command-line tools and direnv/nix-direnv
- `shell/shell.nix`: shell entry point, importing `shell/fish.nix` and retaining Bash as a fallback
- `shell/fish.nix`: Fish settings managed directly through Home Manager
- `tmux/`: `tmux.nix` installs tmux and links the native `.tmux.conf` to `~/.tmux.conf`
- `git/`: native Git configuration, ignore rules, commit template, and `git.nix`
- `neovim/`: native Lua configuration, plugin lockfile, and `neovim.nix`
- `flake.nix` / `flake.lock`: Home Manager entry point and pinned dependencies
- `nixos/desktop.nix`: Hyprland, Quickshell, and login/session settings
- `nixos/`: system configuration and this VM's hardware configuration

## Native Git, Neovim, and tmux configuration

Imported from https://github.com/shana0440/dotfiles at commit
`072b511a2ae5f473e6ff45c795a82fcc922675ce`.

- Edit `git/.gitconfig`, `git/.gitignore_global`, and `git/.gitcommit.template`
  for Git settings. Home Manager links these to the corresponding user locations.
- Edit `neovim/config/init.lua` and `neovim/config/lua/` for editor settings,
  keymaps, and lazy.nvim plugins. Markdown queries and the upstream plugin lockfile
  are included; the old `init.vim.bak` is not used.
- Edit `tmux/.tmux.conf` for terminal colors, mouse support, vi-style keys, and
  extended key handling. This file is also copied from the upstream repo.
- The Nix modules install programs/dependencies and create live, out-of-store
  links for Git, Neovim, tmux, Kitty, and Hyprland. Keep this checkout at
  `~/dotfiles`: the active config files resolve directly to this writable checkout.
  Edits through either path modify the same Git-tracked files.
- Native config edits do not require `make home`: Git reads changes automatically;
  restart Neovim, run `tmux source-file ~/.tmux.conf`, reload Kitty with
  Ctrl+Shift+F5 (or `kill -USR1 <kitty-pid>`), or run `hyprctl reload`.
- New Neovim Lua files also work without switching because the entire config
  directory is linked. Review lazy.nvim lockfile changes before committing.
- Changes to `.nix` files, packages, or link declarations still need `make home`
  (and NixOS system changes need `make nixos`). Fish remains Nix-generated as
  configured in `shell/fish.nix`; do not edit its read-only generated files.
- First Neovim launch downloads plugins and Mason language servers. This requires
  network access. Mason-downloaded binaries may need additional NixOS integration;
  full plugin/LSP compatibility has not been verified.

These modules are shared across Linux, macOS, and WSL. Repository-local Git
settings continue to override user-level defaults.

## Platform profiles

`make home` detects macOS, Linux, or WSL and delegates to `home-mac`,
`home-linux`, or `home-wsl`. WSL is detected via `WSL_DISTRO_NAME` or the kernel
release. The explicit targets select the matching platform file, and Nix's host
architecture selects the flake profile. To bypass OS detection, invoke
`make home-linux`, `make home-mac`, or `make home-wsl` directly. Select any profile with
`make home HOME_CONFIG=<profile>`.

| Profile | Home directory | Desktop settings |
| --- | --- | --- |
| `kwguo-x86_64-linux` | `/home/kwguo` | Kitty + Hyprland config |
| `kwguo-aarch64-linux` | `/home/kwguo` | Kitty + Hyprland config |
| `kwguo-aarch64-darwin` | `/Users/kwguo` | Kitty; no Hyprland |
| `kwguo-x86_64-darwin` | `/Users/kwguo` | Kitty; no Hyprland |
| `kwguo-x86_64-linux-wsl` | `/home/kwguo` | CLI only; use your Windows terminal |
| `kwguo-aarch64-linux-wsl` | `/home/kwguo` | CLI only; use your Windows terminal |

`kwguo` remains an alias for the original x86_64 Linux configuration. Each profile
imports its platform entry point (`home.nix`, `macos.nix`, or `wsl.nix`), which
imports `common.nix`. No environment-dependent imports occur during pure Nix
evaluation. All profiles share Git, Neovim, tmux, Fish/Bash, direnv, and CLI tools.
NixOS system modules under `nixos/` are separate and must not be applied on
macOS or plain WSL. Root-level `applications.nix` exports two separate modules:
NixOS imports its `nixos` attribute; desktop Linux Home Manager imports its
`homeManager` attribute. The macOS and WSL app imports are unchanged.
Both x86_64 and aarch64 are supported. Make selects the host architecture through
`builtins.currentSystem`; explicit targets retain that automatic selection.
Intel macOS uses the pinned 26.05 release, the last Nixpkgs release supporting
`x86_64-darwin`.

Each profile has been evaluated; macOS/WSL builds and runtime behavior still need
testing on those hosts.

## Fish shell

`shell/fish.nix` configures Fish through Home Manager, including standard fzf and
direnv integrations. Shared CLI packages, including fd, live in `programs.nix`.
No separate Fish configuration files or third-party Fish plugins are maintained.

Home Manager installs/configures Fish, but NixOS owns the login shell. Run
`make nixos` to apply `programs.fish.enable` and the account's `shell = pkgs.fish`,
then log out and back in. Until then, run `fish` to try it in the current terminal.
On macOS, changing the login shell is a separate host-specific step.

## Hyprland configuration

Edit `hyprland/hyprland.lua` (or `~/.config/hypr/hyprland.lua`), then run
`hyprctl reload`. After the initial Home Manager activation, no switch is needed
for Lua edits.
Home Manager links it to `~/.config/hypr/hyprland.lua` on desktop Linux only (not WSL);
Hyprland installation and the login session stay in `nixos/desktop.nix`.

## Make targets

From `~/dotfiles`:

```sh
make nixos      # Rebuild and activate NixOS (requires sudo).
make home       # Detect the environment and invoke the matching target.
make home-linux # Apply home.nix.
make home-mac   # Apply macos.nix.
make home-wsl   # Apply wsl.nix.
```

These require GNU Make (`gnumake` in Nixpkgs). If it is not installed, use
`nix-shell -p gnumake --run 'make home'` (or `make nixos`).

## First installation (no sudo)

Choose a profile from the table (this example is Apple Silicon macOS):

```sh
nix run 'https://github.com/nix-community/home-manager/archive/refs/heads/release-26.05.tar.gz' -- switch --flake ~/dotfiles#kwguo-aarch64-darwin
```

New files must be tracked (`git add`) before using a Git-backed flake. No commit
is necessary. For local experiments, `--flake "path:$HOME/dotfiles#<profile>"`
includes untracked files as well.

This installs the Home Manager command and applies user settings. If the command
is not found afterwards, open a new login session or use
`~/.nix-profile/bin/home-manager`.

## Apply application changes

Edit the `homeManager` module in `applications.nix` for Discord, Bitwarden Desktop, Telegram,
Signal, and Anki, then run `make home` without sudo or a NixOS rebuild. This module
is imported only by desktop Linux; macOS and WSL profiles are unchanged.
Packages unavailable for the selected architecture (such as Discord on ARM Linux)
are skipped with a Home Manager warning.

Firefox and Steam remain in its `nixos` module; changes to them still use
`make nixos`. Shared CLI tools remain in `programs.nix`.

To migrate, first run `make home` to install the apps in your user profile.
Then run `make nixos` once
to remove their system-level declarations. Neither step is applied automatically.

## Update pinned Home Manager dependencies

```sh
cd ~/dotfiles
nix flake update
make home
```

Keep `home.stateVersion` unchanged when updating packages.

## NixOS system configuration

Edit `~/dotfiles/nixos/configuration.nix`, then rebuild explicitly from that file:

```sh
sudo nixos-rebuild switch -I nixos-config=/home/kwguo/dotfiles/nixos/configuration.nix
```

The original files in `/etc/nixos/` are unchanged and serve as a backup. A plain
`sudo nixos-rebuild switch` still uses those original files, not this copy.
The system configuration uses the system's nixpkgs channel, independently of the
Home Manager flake lock.

`nixos/hardware-configuration.nix` is specific to this VM; regenerate it for a
new machine. Do not change `system.stateVersion` just to update packages.

## Steam

The `nixos` module in `applications.nix` enables Steam with `programs.steam.enable = true` and
allows unfree packages. Apply with `make nixos` to configure Steam's system
integration, including 32-bit graphics support. Games themselves are managed
without root.
