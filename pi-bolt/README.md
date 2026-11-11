# Pi-Bolt

`agents.nix` replaces upstream Pi with Pi-Bolt on Linux (x86-64/ARM64) and
Apple-silicon macOS. Both `pi` and `pi-bolt` launch it. Intel macOS keeps upstream
Pi because Pi-Bolt does not publish an Intel macOS executable.

An older launcher earlier on `PATH` (such as `~/.pi/agent/bin/pi`) can shadow the
Nix `pi` command. Use `pi-bolt` or `~/.nix-profile/bin/pi` in that case.

Upstream has no flake. The root flake packages its official release archives,
pinned by release URL and `flake.lock`. The x86-64 build uses the baseline variant
so it does not require AVX2.

## Update

Find the latest release at <https://github.com/opensec-git/Pi-Bolt/releases/latest>.
Change `bolt-v1.2.0` in all three Pi-Bolt input URLs in `flake.nix` to the new tag,
then run:

```sh
nix flake update pi-bolt-linux-x64 pi-bolt-linux-arm64 pi-bolt-darwin-arm64
nix build .#pi-bolt
make home
```

`nix flake update` alone refreshes hashes but does not change the explicit release
tag. Do not use `pi-bolt update` for this Nix-managed installation.
