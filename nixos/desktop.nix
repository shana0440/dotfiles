{ config, pkgs, ... }:

let
  hyprland = builtins.getFlake "github:hyprwm/Hyprland/v0.57.2";
  system = pkgs.stdenv.hostPlatform.system;
  hyprlandPkgs = hyprland.inputs.nixpkgs.legacyPackages.${system};
in
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics = {
    enable = true;
    package = hyprlandPkgs.mesa;
  };
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  programs.hyprland = {
    enable = true;
    package = hyprland.packages.${system}.hyprland.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./hyprland-exclusive-layer-focus.patch ];
    });
    portalPackage = hyprland.packages.${system}.xdg-desktop-portal-hyprland;
  };
  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };
  security.pam.services.quickshell-lock = { };
}
