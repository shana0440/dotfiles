{ config, lib, pkgs, ... }:

let
  screenshot = pkgs.writeShellApplication {
    name = "hypr-screenshot";
    runtimeInputs = with pkgs; [ coreutils grim slurp wl-clipboard quickshell ];
    text = builtins.readFile ./scripts/screenshot.sh;
  };
in
{
  home.packages = lib.optionals pkgs.stdenv.isLinux [
    pkgs.cava
    pkgs.grim
    pkgs.slurp
    pkgs.wl-clipboard
    screenshot
  ];

  xdg.configFile."hypr/hyprlock.conf" = lib.mkIf pkgs.stdenv.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.dotfiles.directory}/hyprland/hyprlock.conf";
  };

  xdg.configFile."hypr/hyprland.lua" = lib.mkIf pkgs.stdenv.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.dotfiles.directory}/hyprland/hyprland.lua";
  };
}
