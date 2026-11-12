# Import the appropriate module for NixOS or standalone Home Manager.
{
  nixos = { pkgs, ... }: {
    # Required for Steam.
    nixpkgs.config.allowUnfree = true;

    programs.firefox.enable = true;
    programs.steam.enable = true;

    # UxPlay advertises its AirPlay receiver over mDNS.
    services.avahi = {
      enable = true;
      publish.enable = true;
      publish.userServices = true;
      openFirewall = true;
    };
    networking.firewall.allowedTCPPorts = [ 7000 7001 7100 ];
    networking.firewall.allowedUDPPorts = [ 6000 6001 7011 ];
  };

  homeManager = { lib, pkgs, ... }:
    let
      applications = with pkgs; [
        discord
        bitwarden-desktop
        telegram-desktop
        signal-desktop
        uxplay # AirPlay screen mirroring receiver
      ] ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
        (import ./eagle/package.nix { inherit pkgs; })
        (import ./nexon/package.nix { inherit pkgs; })
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
