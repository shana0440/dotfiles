# User dotfiles

Standalone Home Manager for kwguo on x86_64-linux, using NixOS/Home Manager 26.05.

- `applications.nix`: user application list and unfree-package policy
- `home.nix`: user settings and module imports
- `flake.nix` / `flake.lock`: configuration entry point and pinned dependencies

## First installation (no sudo)

```sh
nix run 'https://github.com/nix-community/home-manager/archive/refs/heads/release-26.05.tar.gz' -- switch --flake ~/dotfiles#kwguo
```

This installs the declared applications and the Home Manager command. If the command
is not found afterwards, open a new login session or use
`~/.nix-profile/bin/home-manager`.

## Apply application changes

Edit `applications.nix`, then run:

```sh
home-manager switch --flake ~/dotfiles#kwguo
```

## Update pinned dependencies and applications

```sh
cd ~/dotfiles
nix flake update
home-manager switch --flake .#kwguo
```

Keep `home.stateVersion` unchanged when updating packages.

## Steam (separate, system-level setup)

Steam is intentionally excluded from Home Manager. Add this inside the top-level
configuration in `/etc/nixos/configuration.nix`:

```nix
nixpkgs.config.allowUnfree = true;
programs.steam.enable = true;
```

Then run `sudo nixos-rebuild switch`. This enables Steam's system integration,
including 32-bit graphics support; games themselves are managed without root.

Firefox is currently also enabled in the system configuration. Leaving it there
is harmless, but removing `programs.firefox.enable` during a future system rebuild
will make Home Manager the sole manager of the Firefox package.
