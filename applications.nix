# Import the appropriate module for NixOS or standalone Home Manager.
{
  nixos = { pkgs, ... }: {
    # Required for Steam.
    nixpkgs.config.allowUnfree = true;

    programs.firefox.enable = true;
    programs.steam.enable = true;

    programs.appimage = {
      enable = true;
      binfmt = true;
      package = import ./appimage/package.nix { inherit pkgs; };
    };
  };

  homeManager = { lib, pkgs, ... }:
    let
      applications = with pkgs; [
        file-roller
        discord
        bitwarden-desktop
        telegram-desktop
        signal-desktop
      ] ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
        (import ./eagle/package.nix { inherit pkgs; })
        (import ./nexon/package.nix { inherit pkgs; })
      ];
      supported = pkg: lib.meta.availableOn pkgs.stdenv.hostPlatform pkg;
      appimageRun = import ./appimage/package.nix { inherit pkgs; };
    in {
      imports = [ ./appimage/home.nix ];

      # Required for proprietary applications such as Discord.
      nixpkgs.config.allowUnfree = true;

      home.packages = builtins.filter supported applications
        ++ lib.optional pkgs.stdenv.hostPlatform.isLinux appimageRun;

      # Open archives in the graphical archive manager.
      home.activation.archiveDefaultHandler = lib.mkIf pkgs.stdenv.hostPlatform.isLinux
        (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          run ${pkgs.xdg-utils}/bin/xdg-mime default org.gnome.FileRoller.desktop application/zip
          run ${pkgs.xdg-utils}/bin/xdg-mime default org.gnome.FileRoller.desktop application/x-zip-compressed
          run ${pkgs.xdg-utils}/bin/xdg-mime default org.gnome.FileRoller.desktop application/x-7z-compressed
        '');

      home.activation.appimageDefaultRunner = lib.mkIf pkgs.stdenv.hostPlatform.isLinux
        (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          run ${pkgs.xdg-utils}/bin/xdg-mime default appimage-run.desktop application/vnd.appimage
          run ${pkgs.xdg-utils}/bin/xdg-mime default appimage-run.desktop application/x-iso9660-appimage
        '');

      warnings = map
        (pkg: "Skipping ${pkg.pname}: unavailable on ${pkgs.stdenv.hostPlatform.system}.")
        (builtins.filter (pkg: !supported pkg) applications);
    };
}
