# Mount the NAS at `/mnt/nas`

NAS support is optional and configured by `nixos/nas.nix`. It uses **NFSv4.0**
over TCP, with an on-demand read/write mount.

## Configure Synology

1. Enable NFSv4 in **Control Panel → File Services → NFS**.
2. In **Shared Folder → Edit → NFS Permissions**, allow this desktop's LAN IP.
3. Enable read/write access and ensure the desktop user can access the library.
   NFS uses numeric user/group IDs, not the SMB username/password. Configure
   server-side permissions or identity mapping deliberately; do not change library
   ownership recursively just to make a test work.
4. Note the export path displayed by DSM (for example, `/volume1/homes`).

A temporary “map all users to admin” rule used during read-only testing is not a
recommended production permission model. Prefer a dedicated library share with
appropriately scoped permissions. Restrict the export to trusted clients; allowing
an IP with `sec=sys` trusts the client to supply user IDs. NFS traffic here is not
encrypted or authenticated with SMB credentials.

## Configure the device secret

From the dotfiles directory, copy the example **only for initial setup**:

```sh
install -m 600 nixos/nas/secrets.example.yaml nixos/nas/secrets.yaml
vim nixos/nas/secrets.yaml
```

Set `device` to `NAS_HOST:/EXPORT/PATH`. For a library currently accessed through
Synology's SMB `home` share, use the user's subdirectory of the `homes` export:

```yaml
device: "NAS_HOST:/volume1/homes/YOUR_NAS_USERNAME"
```

This keeps `/mnt/nas/Eagle/...` unchanged; mounting all of `homes` would add an
extra username directory. Use the actual volume/export path from DSM.

`secrets.yaml` is Git-ignored; never commit it. NFS needs only the `device` key;
the former SMB `credentials` key is no longer used.

## Enable or migrate the mount

Set this in `nixos/configuration.nix` on machines that need NAS access:

```nix
services.nas.enable = true;
```

For an existing SMB configuration, change `device` in `secrets.yaml` from
`//HOST/home` to the NFS path above and remove the unused `credentials` key. Do
not overwrite existing secrets with the example.

Close Eagle and any other applications using the NAS, then run:

```sh
make nixos
ls /mnt/nas
findmnt -T /mnt/nas
```

Verify the mounted filesystem is NFSv4 and verify read/write permissions before
opening Eagle. After testing, remove the separate read-only test mount with
`sudo umount /mnt/nas-nfs` when nothing is using it.

The `nas-automount` service reads `nixos/nas/secrets.yaml` at runtime by its
absolute path, so the file must stay in this checkout. After editing it, run
`sudo systemctl restart nas-automount`. Accessing `/mnt/nas` connects automatically and keeps it mounted,
even when idle. Other machines can leave NAS support disabled.

The mount uses `hard` semantics: an unavailable NAS can block file operations
while the client retries. The systemd mount timeout is not an I/O timeout; avoid
`soft` mounts for a writable Eagle library because failed operations can risk
incomplete writes.

**Privacy:** the secrets file stays out of the Nix store, but the address is
visible in runtime mount information.

**Troubleshooting:** `journalctl -b -u nas-automount -u mnt-nas.mount`

## Performance check

A read-only Wine directory-listing comparison of the same 27,942 library entries
returned identical filenames in 90.6 seconds over SMB versus 20.3 and 19.8 seconds
over NFSv4.0. This measures the metadata-heavy startup operation, not full Eagle
startup or write compatibility. Results: `~/.local/state/eagle-startup-test/nfs-results.json`.
