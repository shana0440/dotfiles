# User dotfiles

Standalone Home Manager for kwguo on x86_64-linux, using NixOS/Home Manager 26.05.

- `nixos/applications.nix`: system application list, Firefox/Steam integration, and unfree-package policy
- `home.nix`: user settings and module imports
- `programs.nix`: portable command-line tools (GNU Make, fzf, and ripgrep)
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
- The Nix modules install programs/dependencies and link files; Git settings and
  Neovim Lua are not generated from Nix. Apply edits with `make home`.
- Keep this checkout at `~/dotfiles`: the Neovim plugin lockfile is linked directly
  to the writable checkout so lazy.nvim can update it. Other configuration files
  are linked through the Nix store. Review lockfile updates before committing.
- First Neovim launch downloads plugins and Mason language servers. This requires
  network access. Mason-downloaded binaries may need additional NixOS integration;
  full plugin/LSP compatibility has not been verified.

Both modules are usable with Home Manager on NixOS and macOS. The current flake
and home directory settings still target Linux. Repository-local Git settings
continue to override user-level defaults.

## Make targets

From `~/dotfiles`:

```sh
make nixos # Rebuild and activate NixOS (requires sudo).
make home  # Apply standalone Home Manager (no sudo).
```

These require GNU Make (`gnumake` in Nixpkgs). If it is not installed, use
`nix-shell -p gnumake --run 'make home'` (or `make nixos`).

## First installation (no sudo)

```sh
nix run 'https://github.com/nix-community/home-manager/archive/refs/heads/release-26.05.tar.gz' -- switch --flake ~/dotfiles#kwguo
```

This installs the Home Manager command and applies user settings. If the command
is not found afterwards, open a new login session or use
`~/.nix-profile/bin/home-manager`.

## Apply application changes

Applications are now system-managed. Edit `nixos/applications.nix`, then run
`make nixos`. Use `make home` for user settings in `home.nix`.

When migrating from the previous Home Manager application list, run `make nixos`
first to install the system packages, then `make home` to remove the old user-level
packages. Neither step has been applied automatically.

## Update pinned Home Manager dependencies

```sh
cd ~/dotfiles
nix flake update
home-manager switch --flake .#kwguo
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

`nixos/applications.nix` enables Steam with `programs.steam.enable = true` and
allows unfree packages. Apply with `make nixos` to configure Steam's system
integration, including 32-bit graphics support. Games themselves are managed
without root.
