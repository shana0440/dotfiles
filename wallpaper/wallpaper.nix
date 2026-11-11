{ config, pkgs, ... }:

let
  # One interpreter for every wallpaper command: thumbnails (ImageMagick
  # subprocess) plus colony maps and accent colours (NumPy, Pillow).
  python = pkgs.python3.withPackages (ps: [ ps.numpy ps.pillow ]);
  library = pkgs.writeShellApplication {
    name = "wallpaper-library";
    runtimeInputs = [ pkgs.imagemagick ];
    text = ''
      export WALLPAPER_DIR="''${WALLPAPER_DIR:-${config.home.homeDirectory}/Pictures/Wallpapers}"
      exec ${python}/bin/python3 ${./library.py} "$@"
    '';
  };
  colonies = pkgs.writeShellApplication {
    name = "wallpaper-colonies";
    text = ''
      exec ${python}/bin/python3 ${./colonies.py} "$@"
    '';
  };
  setWallpaper = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = [ pkgs.awww ];
    text = ''
      exec ${python}/bin/python3 ${./library.py} set "$@"
    '';
  };
  check = pkgs.writeShellApplication {
    name = "wallpaper-check";
    runtimeInputs = [ pkgs.imagemagick ];
    text = ''
      ${python}/bin/python3 ${./test_library.py} ${./library.py} "$@"
      ${python}/bin/python3 ${./test_colonies.py} ${./colonies.py} "$@"
    '';
  };
in
{
  # Installs the client and runs the daemon as a user service.
  # Hyprland explicitly starts it because this session does not activate
  # graphical-session.target (see hyprland/hyprland.lua).
  services.awww.enable = true;
  home.packages = [ library colonies setWallpaper check ];
}
