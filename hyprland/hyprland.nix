{ config, lib, pkgs, ... }:

{
  xdg.configFile."hypr/hyprlock.conf" = lib.mkIf pkgs.stdenv.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.dotfiles.directory}/hyprland/hyprlock.conf";
  };

  xdg.configFile."hypr/hyprland.lua" = lib.mkIf pkgs.stdenv.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.dotfiles.directory}/hyprland/hyprland.lua";
  };
}
