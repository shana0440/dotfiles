# Mount the NAS at `/mnt/nas`

NAS support is optional and configured by `nixos/nas.nix`.

## Configure the NAS

From the dotfiles directory, copy the example **only for initial setup**:

```sh
install -m 600 nixos/nas/secrets.example.yaml nixos/nas/secrets.yaml
vim nixos/nas/secrets.yaml
```

Replace:

- `NAS_HOST`: the NAS's LAN IP or hostname, not its QuickConnect web address.
- `YOUR_NAS_USERNAME`: your NAS account.
- `YOUR_NAS_PASSWORD`: its password, literally without quotes in the credentials block.

Keep `//HOST/home` as the device to mount the authenticated Synology user's home
share. NAS permissions still determine which files the account can access.

Follow the root README's [Secrets (SOPS)](../../README.md#secrets-sops) guide to
encrypt this configuration into `nixos/nas/secrets.enc.yaml`. For system-level
decryption, the corresponding private age key must exist at
`/var/lib/sops-nix/key.txt`, owned by root with permissions `0600`.

## Enable the mount

Set this in `nixos/configuration.nix` on machines that need NAS access:

```nix
services.nas.enable = true;
```

Then run:

```sh
make nixos
ls /mnt/nas
```

NixOS decrypts `secrets.enc.yaml` at runtime; it does not use your plaintext copy.
Accessing `/mnt/nas` connects automatically with read/write access and keeps it
mounted, even when idle. Other machines can leave NAS support disabled.

After changing the encrypted configuration, close files using the NAS and run
`make nixos` again.

**Privacy:** secrets stay out of the Nix store, but the address is visible in
runtime mount information. These settings do not guarantee encrypted SMB traffic.

**Troubleshooting:** `journalctl -b -u sops-install-secrets -u nas-automount -u mnt-nas.mount`
