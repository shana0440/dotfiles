# Import the appropriate module for NixOS or standalone Home Manager.
{
  homeManager = { pkgs, ... }: {
    home.packages = [
      pkgs.proton-vpn
      (import ./windscribe.nix { inherit pkgs; })
    ];
  };

  nixos = { config, pkgs, ... }:
    let
      windscribe = import ./windscribe.nix { inherit pkgs; helper = true; };
    in {
      networking.networkmanager = {
        enable = true;
        plugins = [ pkgs.networkmanager-openvpn ];
        dns = "systemd-resolved";
      };
      services.resolved.enable = true;
      services.gnome.gnome-keyring.enable = true;

      # The helper socket is restricted to this group. Avoid setgid binaries.
      users.groups.windscribe = { };
      users.users.windscribe = {
        isSystemUser = true;
        group = "windscribe";
      };
      users.users.${config.user.name}.extraGroups = [ "windscribe" ];

      environment.etc."windscribe/platform".text =
        if pkgs.stdenv.hostPlatform.isAarch64 then "linux_deb_arm64\n"
        else "linux_deb_x64\n";

      systemd.services.windscribe-helper = {
        description = "Windscribe VPN privileged helper";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-pre.target" ];
        before = [ "network-pre.target" ];
        serviceConfig = {
          ExecStart = "${windscribe}/bin/windscribe";
          Restart = "on-failure";
        };
      };
    };
}
