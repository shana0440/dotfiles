# User dotfiles

Standalone Home Manager for kwguo on x86_64-linux, using NixOS/Home Manager 26.05.

- `nixos/applications.nix`: system application list, Firefox/Steam integration, and unfree-package policy
- `home.nix`: user settings and module imports
- `programs.nix`: portable command-line tools (GNU Make, fzf, and ripgrep)
- `git.nix`: portable Home Manager Git configuration (name and email)
- `vim.nix`: portable Home Manager Neovim configuration and vi/vim aliases
- `flake.nix` / `flake.lock`: Home Manager entry point and pinned dependencies
- `nixos/desktop.nix`: Hyprland, Quickshell, and login/session settings
- `nixos/`: system configuration and this VM's hardware configuration

## Shared Git configuration

`git.nix` is a Home Manager module usable on both NixOS and macOS. Import it in
any Home Manager configuration to install Git and apply the shared identity.
The current `flake.nix` and `home.nix` target Linux; macOS needs its own Home
Manager output and home directory settings. Apply locally with `make home`.
Repository-local Git settings override these user-level defaults.

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
