{ config, pkgs, ... }:

let
  hyprland = builtins.getFlake "github:hyprwm/Hyprland/v0.57.2";
  system = pkgs.stdenv.hostPlatform.system;
  hyprlandPkgs = hyprland.inputs.nixpkgs.legacyPackages.${system};
  hyprlandPackage = hyprland.packages.${system}.hyprland.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./hyprland-exclusive-layer-focus.patch ];
  });
  hyprlandPluginsSource = builtins.fetchTarball {
    url = "https://github.com/hyprwm/hyprland-plugins/archive/2e03a09a92ba8b0adcd2840a69d84ffc2174b886.tar.gz";
    sha256 = "0cwqs13irrlbp1qw6ps5pylms56xzlzis9kizy5sqph1c43afigj";
  };
  hyprbars = hyprlandPkgs.hyprlandPlugins.mkHyprlandPlugin {
    pluginName = "hyprbars";
    version = "0.57.2";
    src = "${hyprlandPluginsSource}/hyprbars";
    patches = [ ./hyprbars-idle-button-color.patch ./hyprbars-button-cursor.patch ];
    hyprland = hyprlandPackage;
    inherit (hyprlandPackage) nativeBuildInputs;
    meta.description = "Hyprland window title bars";
  };
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
    package = hyprlandPackage;
    portalPackage = hyprland.packages.${system}.xdg-desktop-portal-hyprland;
  };
  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };
  environment.etc."hyprland/plugins/hyprbars.so".source = "${hyprbars}/lib/libhyprbars.so";
  security.pam.services.quickshell-lock = { };
}
