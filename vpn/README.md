# VPN

`vpn.nix` exports `homeManager` and `nixos` modules, imported by the desktop
Linux profiles. macOS and WSL are unchanged.

- Home Manager installs Proton VPN (`protonvpn-app`), Windscribe (`windscribe`),
  their application-menu entries, and `windscribe-cli`.
- NixOS enables NetworkManager/OpenVPN, systemd-resolved for VPN-aware DNS,
  GNOME Keyring for Proton credentials, and Windscribe's root helper service.
  The desktop user joins the `windscribe` group to access its helper socket.
- `windscribe.nix` pins upstream 2.24.13 Debian binaries for x86_64 and aarch64,
  with verified download hashes. An FHS environment preserves upstream's
  `/opt/windscribe` paths without writing into the host's `/opt` directory.
  The service variant preserves root capabilities needed to manage networking.

Apply with `make nixos` and `make home-linux`, then log out and back in for
the new group membership and keyring session. Open either app and sign in.
Use only one VPN connection at a time; neither app is configured to connect
automatically. Update Windscribe through this Nix package, not its in-app updater.
Standalone non-NixOS Linux hosts need the equivalent host services separately.

## Validation

Both x86_64 packages build. Home Manager package selection and the NixOS helper,
DNS, keyring, and group configuration are evaluated. In a headless X11 agent
workspace, Proton displays its login form and Windscribe displays its expected
missing-helper error before the NixOS service is applied. Actual login, tunnel
connections, DNS leak protection, and aarch64 runtime behavior are not tested.
No VPN was connected and no running host services were changed during testing.
