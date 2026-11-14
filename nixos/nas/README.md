# NAS mount at `/mnt/nas`

Optional NFSv4.0 mount from a Synology NAS, configured by `nixos/nas.nix`.
Disable it with `services.nas.enable = false;` in `nixos/configuration.nix` on
machines without a NAS.

## 1. Synology

1. **Control Panel → File Services → NFS**: enable NFSv4.
2. **Shared Folder → Edit → NFS Permissions**: allow this machine's LAN IP with
   read/write.
3. NFS checks numeric user/group IDs, not SMB logins. Make sure your Linux UID
   can access the files (set server-side permissions or mapping; avoid "map all
   users to admin").
4. Note the export path DSM shows, e.g. `/volume1/homes`.

NFS here is unencrypted and trusts the client's user IDs; only allow trusted
clients.

## 2. Secret

From `~/dotfiles`:

```sh
install -m 600 nixos/nas/secrets.example.yaml nixos/nas/secrets.yaml
```

Set `device` to `NAS_HOST:/EXPORT/PATH`, for example:

```yaml
device: "NAS_HOST:/volume1/homes/YOUR_NAS_USERNAME"
```

After changing it later, run `sudo systemctl restart nas-automount`.

## 3. Apply and check

```sh
make nixos
findmnt -T /mnt/nas   # should show nfs4
```

If the NAS goes offline, programs reading `/mnt/nas` wait until it returns.
