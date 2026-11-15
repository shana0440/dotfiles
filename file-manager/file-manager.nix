{
  nixos = { pkgs, ... }: {
    services.gvfs.enable = true;

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
      gnomeThumbnailers = [ pkgs.glycin-thumbnailer pkgs.gst-thumbnailers pkgs.papers ];
    in {
      imports = [ ./appimage/home.nix ];

      home.packages = [
        pkgs.nautilus
        pkgs.file-roller
        appimageRun
      ] ++ gnomeThumbnailers;

      home.activation.fileManagerDefaultHandler = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${xdgMime} default org.gnome.Nautilus.desktop inode/directory
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
