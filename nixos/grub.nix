{ ... }:

{
  # Keep GRUB on the NixOS EFI partition and chainload the Windows EFI partition.
  boot.loader = {
    systemd-boot.enable = false;

    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };

    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      configurationLimit = 5;

      extraEntries = ''
        menuentry "Windows Boot Manager" {
          insmod part_gpt
          insmod fat
          insmod chain
          search --no-floppy --fs-uuid --set=root DADD-51ED
          chainloader /EFI/Microsoft/Boot/bootmgfw.efi
        }
      '';
    };

    timeout = 5;
  };
}
