# Install NixOS alongside Windows

For a GPT disk that already holds Windows and has unallocated space for NixOS.
NixOS gets its own 1 GiB EFI partition and an ext4 root; Windows partitions are
not touched. GRUB (`nixos/grub.nix`) boots both.

**Back up Windows first, save your BitLocker recovery key, and disable Windows
Fast Startup. The format commands erase the two new partitions; check every
device name before running them.**

## 1. Prepare (live installer, Bash)

Boot the NixOS live installer, copy or clone this repo, `cd` into it, and run
`bash` if the shell is Fish. Apply the username edits from the root
[README](../README.md#before-you-start-username) first.

Inspect the disk and its free region:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,UUID,PARTLABEL
sudo parted /dev/nvme0n1 unit s print free   # use your disk
```

Set these from that output (example values shown):

```bash
USERNAME=kwguo        # must match nixos/user.nix
DISK=/dev/nvme0n1
EFI=/dev/nvme0n1p5    # name the first new partition will get
ROOT=/dev/nvme0n1p6   # name the second new partition will get
EFI_NUM=5             # partition number of $EFI
START=1909989376      # first free sector
END=1998528511        # last free sector
EFI_END=$((START + 2097151))   # 1 GiB of 512-byte sectors
```

In `nixos/grub.nix`, replace the UUID in `search --fs-uuid --set=root ...` with
the UUID of the **Windows** EFI partition (the existing `vfat` partition).

## 2. Partition, install, reboot

Run in order; **stop if any command fails.**

```bash
sudo parted --script "$DISK" unit s mkpart NixOS-ESP fat32 "${START}s" "${EFI_END}s"
sudo parted --script "$DISK" set "$EFI_NUM" esp on
sudo parted --script "$DISK" unit s mkpart NixOS-root ext4 "$((EFI_END + 1))s" "${END}s"
sudo udevadm settle

sudo mkfs.fat -F 32 -n NIXOS_EFI "$EFI"
sudo mkfs.ext4 -L nixos-root "$ROOT"

sudo mount "$ROOT" /mnt
sudo mkdir -p /mnt/boot
sudo mount "$EFI" /mnt/boot

sudo mkdir -p "/mnt/home/$USERNAME/dotfiles"
sudo cp -a . "/mnt/home/$USERNAME/dotfiles/"

sudo nixos-generate-config --root /mnt
sudo cp /mnt/etc/nixos/hardware-configuration.nix "/mnt/home/$USERNAME/dotfiles/nixos/"

# Make plain `nixos-rebuild` use the dotfiles too.
sudo tee /mnt/etc/nixos/configuration.nix > /dev/null <<EOF
{ ... }: { imports = [ ../../home/$USERNAME/dotfiles/nixos/configuration.nix ]; }
EOF

sudo nixos-install --root /mnt                          # prompts for the root password
sudo nixos-enter --root /mnt -c "passwd $USERNAME"      # user password (sudo, unlock)
sudo nixos-enter --root /mnt -c "chown -R $USERNAME:users /home/$USERNAME"

sync
sudo umount -R /mnt
sudo reboot
```

If the firmware boots Windows directly, pick the NixOS entry in its boot menu
or change the boot order.

## 3. First login

Log in as your user (no sudo) and apply Home Manager:

```bash
cd ~/dotfiles
export NIX_CONFIG='extra-experimental-features = nix-command flakes'
nix run 'https://github.com/nix-community/home-manager/archive/refs/heads/release-26.05.tar.gz' -- \
  switch -b backup --flake ".#$USER-x86_64-linux"
```

Log out and back in. From now on use `make home` and `make nixos` (see the root
README).
