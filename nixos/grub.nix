{ pkgs, ... }:

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

      # The firmware exposes 720p, but not the monitor's native 4K mode.
      gfxmodeEfi = "1280x720,auto";
      theme = pkgs.runCommand "grub-sunset-theme" {
        nativeBuildInputs = [ pkgs.grub2 ];
      } ''
        mkdir -p "$out"
        cp ${./grub-theme}/* "$out/"
        for size in 14 18 28; do
          grub-mkfont -s "$size" -o "$out/dejavu-$size.pf2" \
            ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf
        done
      '';

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
