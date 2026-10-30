# Install NixOS alongside Windows

Run these commands in **Bash in the live NixOS installer**. They are specific to this PC's current disk layout: `/dev/nvme0n1`, existing Windows partitions p1–p4, and the unallocated region from sector 1909989376 through 1998528511 (512-byte sectors).

**Back up important Windows files first. Save your BitLocker/device-encryption recovery key if applicable, and disable Windows Fast Startup. The formatting commands erase p5 and p6. Run the partitioning/formatting section only once, on the original layout—not after an interrupted installation. These commands must not be used on a different disk layout.**

Windows partitions p1–p4 are retained. The new p5 is a 1 GiB EFI partition; p6 uses the remaining free region for ext4 root. Zram, username `kwguo`, disabled SSH, and automatic login are already configured in the checkout.

## In the live installer

Start Bash if your current shell is Fish:

```bash
bash
```

Then run the following commands in order. **Stop if any command fails; do not continue to the next one.** Password prompts require interaction.

```bash
# Use the current dotfiles checkout.
cd /home/nixos/Desktop/dotfiles

# Create a 1 GiB NixOS EFI partition in the existing unallocated space.
# This becomes /dev/nvme0n1p5; do not create a new partition table.
sudo parted --script /dev/nvme0n1 unit s mkpart NixOS-ESP fat32 1909989376s 1912086527s
sudo parted --script /dev/nvme0n1 set 5 esp on

# Create the NixOS root partition in the remainder of that free region.
# This becomes /dev/nvme0n1p6, ending immediately before Windows recovery p4.
sudo parted --script /dev/nvme0n1 unit s mkpart NixOS-root ext4 1912086528s 1998528511s
sudo udevadm settle

# Format ONLY the two newly created partitions. Do not format p1–p4.
sudo mkfs.fat -F 32 -n NIXOS_EFI /dev/nvme0n1p5
sudo mkfs.ext4 -L nixos-root /dev/nvme0n1p6

# Mount the installation root, then its separate EFI partition.
# Mounting itself does not erase data.
sudo mount /dev/nvme0n1p6 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/nvme0n1p5 /mnt/boot

# Copy the entire checkout, including local changes, into the future home.
sudo mkdir -p /mnt/home/kwguo/dotfiles
sudo cp -a . /mnt/home/kwguo/dotfiles/

# Generate this PC's root/EFI UUID mounts and hardware configuration.
sudo nixos-generate-config --root /mnt
sudo cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/kwguo/dotfiles/nixos/hardware-configuration.nix

# Limit EFI boot generations and make plain future rebuilds use the dotfiles.
# The relative path resolves to /home/kwguo/dotfiles inside the installed system.
sudo tee /mnt/etc/nixos/configuration.nix > /dev/null <<'EOF'
{ ... }: {
  imports = [ ../../home/kwguo/dotfiles/nixos/configuration.nix ];
  boot.loader.systemd-boot.configurationLimit = 5;
}
EOF

# Install NixOS into /mnt. This also installs systemd-boot on the NEW EFI partition.
# Enter the ROOT password when nixos-install prompts for it.
sudo nixos-install --root /mnt

# Set the normal user's password separately (needed for sudo and screen unlock).
sudo nixos-enter --root /mnt -c 'passwd kwguo'

# Give kwguo ownership of their home and writable dotfiles checkout.
sudo nixos-enter --root /mnt -c 'chown -R kwguo:users /home/kwguo'

# Flush writes, unmount, and reboot. Remove the installer USB as appropriate.
sync
sudo umount -R /mnt
sudo reboot
```

Installation may change UEFI boot priority. Since Windows and NixOS have separate EFI partitions, Windows may not appear in systemd-boot's menu. Use your firmware boot menu to choose **Windows Boot Manager** or **Linux Boot Manager**. Test both operating systems.

## After booting the installed NixOS

Open a terminal as **kwguo**, without sudo. The Home Manager command installed in the live installer does not carry over automatically.

```bash
# Start Bash for the commands below if your terminal uses Fish.
bash
```

```bash
# Activate Home Manager for the installed kwguo user.
cd /home/kwguo/dotfiles
export DOTFILES="$PWD"
export NIX_CONFIG="${NIX_CONFIG:-}
extra-experimental-features = nix-command flakes"
nix run 'https://github.com/nix-community/home-manager/archive/refs/heads/release-26.05.tar.gz' -- \
  switch -b backup --impure --flake "$DOTFILES#current-x86_64-linux"
```

For later configuration changes:

```bash
cd /home/kwguo/dotfiles

# Apply Home Manager changes, without sudo.
make home

# Apply system changes using /etc/nixos/configuration.nix, including its boot limit.
sudo nixos-rebuild switch
```

The installation uses zram at 25% of RAM and no disk swapfile. You can change that later. Keep the checkout at `/home/kwguo/dotfiles`; future rebuilds and Home Manager configuration links depend on it. This trial installation has limited disk space, so keep Steam games elsewhere and manage old NixOS generations as needed.
