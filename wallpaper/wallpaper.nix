{ config, pkgs, ... }:

let
  library = pkgs.writeShellApplication {
    name = "wallpaper-library";
    runtimeInputs = [ pkgs.imagemagick ];
    text = ''
      export WALLPAPER_DIR="''${WALLPAPER_DIR:-${config.home.homeDirectory}/Pictures/Wallpapers}"
      exec ${pkgs.python3}/bin/python3 ${./library.py} "$@"
    '';
  };
  setWallpaper = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = [ pkgs.awww ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./library.py} set "$@"
    '';
  };
in
{
  # Installs the client and runs the daemon as a user service.
  # Hyprland explicitly starts it because this session does not activate
  # graphical-session.target (see hyprland/hyprland.lua).
  services.awww.enable = true;
  home.packages = [ library setWallpaper ];
}
