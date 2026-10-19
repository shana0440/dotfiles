# Hyprland itself is enabled in the NixOS desktop module.
# Manage its native Lua configuration on Linux, not macOS.
{ config, lib, pkgs, ... }:

{
  xdg.configFile."hypr/hyprland.lua" = lib.mkIf pkgs.stdenv.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/hyprland/hyprland.lua";
  };
}
