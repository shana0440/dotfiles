# Hyprland itself is enabled in the NixOS desktop module.
# Manage its native Lua configuration on Linux, not macOS.
{ config, lib, pkgs, ... }:

{
  # Frequency analysis for Quickshell's media visualizers.
  home.packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.cava ];

  xdg.configFile."hypr/hyprlock.conf" = lib.mkIf pkgs.stdenv.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.dotfiles.directory}/hyprland/hyprlock.conf";
  };

  xdg.configFile."hypr/hyprland.lua" = lib.mkIf pkgs.stdenv.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.dotfiles.directory}/hyprland/hyprland.lua";
  };
}
