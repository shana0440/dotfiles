# Hyprland itself is enabled in the NixOS desktop module.
# Manage its native Lua configuration on Linux, not macOS.
{ lib, pkgs, ... }:

{
  xdg.configFile."hypr/hyprland.lua" = lib.mkIf pkgs.stdenv.isLinux {
    source = ./hyprland.lua;
  };
}
