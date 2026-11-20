{
  nixos = { pkgs, ... }: {
    nixpkgs.config.allowUnfree = true;

    programs.steam.enable = true;

    services.avahi = {
      enable = true;
      publish.enable = true;
      publish.userServices = true;
      openFirewall = true;
    };
    networking.firewall.allowedTCPPorts = [ 7000 7001 7100 ];
    networking.firewall.allowedUDPPorts = [ 6000 6001 7011 ];
  };

  homeManager = { inputs, lib, pkgs, zen-browser, ... }:
    let
      applications = with pkgs; [
        brave
        discord
        bitwarden-desktop
        telegram-desktop
        signalInTray
        remmina
        uxplay
        zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta
        (pkgs.anki.withAddons [
          (pkgs.ankiAddons.anki-connect.withConfig {
            config = {
              webBindAddress = "127.0.0.1";
              webBindPort = 8765;
              webCorsOriginList = [ "http://localhost" ];
            };
          })
        ])
      ] ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
        inputs.self.packages.x86_64-linux.eagle
        (import ./nexon/package.nix { inherit pkgs; })
      ];
      supported = pkg: lib.meta.availableOn pkgs.stdenv.hostPlatform pkg;

      signalInTray = pkgs.symlinkJoin {
        name = "signal-desktop-in-tray";
        paths = [ pkgs.signal-desktop ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = "wrapProgram $out/bin/signal-desktop --add-flags --use-tray-icon";
        inherit (pkgs.signal-desktop) meta;
      };
    in {
      nixpkgs.config.allowUnfree = true;

      home.packages = builtins.filter supported applications;

      warnings = map
        (pkg: "Skipping ${pkg.pname}: unavailable on ${pkgs.stdenv.hostPlatform.system}.")
        (builtins.filter (pkg: !supported pkg) applications);
    };
}
