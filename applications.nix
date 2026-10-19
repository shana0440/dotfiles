# Import the appropriate module for NixOS or standalone Home Manager.
{
  nixos = { ... }: {
    # Required for Steam.
    nixpkgs.config.allowUnfree = true;

    programs.firefox.enable = true;
    programs.steam.enable = true;
  };

  homeManager = { lib, pkgs, ... }:
    let
      applications = with pkgs; [
        discord
        bitwarden-desktop
        telegram-desktop
        signal-desktop
        anki
      ];
      supported = pkg: lib.meta.availableOn pkgs.stdenv.hostPlatform pkg;
    in {
      # Required for proprietary applications such as Discord.
      nixpkgs.config.allowUnfree = true;

      home.packages = builtins.filter supported applications;

      warnings = map
        (pkg: "Skipping ${pkg.pname}: unavailable on ${pkgs.stdenv.hostPlatform.system}.")
        (builtins.filter (pkg: !supported pkg) applications);
    };
}
