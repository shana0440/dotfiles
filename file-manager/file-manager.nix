# File manager and the handlers it opens files with: Thunar for folders,
# File Roller for archives, and appimage-run for AppImages.
# Import the appropriate module for NixOS or standalone Home Manager.
{
  nixos = { pkgs, ... }: {
    programs.appimage = {
      enable = true;
      binfmt = true;
      package = import ./appimage/package.nix { inherit pkgs; };
    };
  };

  homeManager = { lib, pkgs, ... }:
    let
      xdgMime = "${pkgs.xdg-utils}/bin/xdg-mime";
      appimageRun = import ./appimage/package.nix { inherit pkgs; };
    in {
      imports = [ ./appimage/home.nix ];

      home.packages = [ pkgs.thunar pkgs.xfconf pkgs.file-roller appimageRun ];

      # Update only these handlers; other application associations remain user-managed.
      home.activation.fileManagerDefaultHandler = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${xdgMime} default thunar.desktop inode/directory
      '';

      home.activation.archiveDefaultHandler = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${xdgMime} default org.gnome.FileRoller.desktop application/zip
        run ${xdgMime} default org.gnome.FileRoller.desktop application/x-zip-compressed
        run ${xdgMime} default org.gnome.FileRoller.desktop application/x-7z-compressed
      '';

      home.activation.appimageDefaultRunner = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${xdgMime} default appimage-run.desktop application/vnd.appimage
        run ${xdgMime} default appimage-run.desktop application/x-iso9660-appimage
      '';
    };
}
