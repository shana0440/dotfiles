{ config, lib, pkgs, ... }:

let
  publishShaderPathForLiveReload = import ../quickshell/publish-shader-path.nix { inherit lib; };
  python = pkgs.python3.withPackages (ps: [ ps.numpy ps.pillow ]);
  library = pkgs.writeShellApplication {
    name = "wallpaper-library";
    runtimeInputs = [ pkgs.imagemagick pkgs.ffmpeg-headless ];
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
  shader = pkgs.runCommand "wallpaper-colonies.frag.qsb" {
    nativeBuildInputs = [ pkgs.qt6.qtshadertools ];
  } ''
    qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$out" ${./colonies.frag}
  '';
  setWallpaper = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = [ pkgs.awww pkgs.quickshell pkgs.ffmpeg-headless pkgs.mpvpaper colonies ];
    text = ''
      exec ${python}/bin/python3 ${./library.py} set "$@"
    '';
  };
  videoWallpaper = pkgs.writeShellApplication {
    name = "wallpaper-video";
    runtimeInputs = [ pkgs.awww pkgs.mpvpaper ];
    text = ''
      exec ${python}/bin/python3 ${./library.py} video "$@"
    '';
  };
in
{
  services.awww.enable = true;
  home.activation.publishColoniesShader = publishShaderPathForLiveReload
    "${config.xdg.configHome}/wallpaper/colonies-shader" shader;
  home.packages = [ library colonies setWallpaper videoWallpaper ];
}
