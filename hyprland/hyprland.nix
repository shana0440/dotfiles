{ config, lib, pkgs, ... }:

let
  screenshot = pkgs.writeShellApplication {
    name = "hypr-screenshot";
    runtimeInputs = with pkgs; [ coreutils grim slurp wl-clipboard quickshell ];
    text = builtins.readFile ./scripts/screenshot.sh;
  };
  recordingFinished = pkgs.writeShellApplication {
    name = "hypr-recording-finished";
    runtimeInputs = with pkgs; [ coreutils ffmpeg quickshell ];
    text = builtins.readFile ./scripts/recording_finished.sh;
  };
  recording = pkgs.writeShellApplication {
    name = "hypr-record";
    runtimeInputs = with pkgs; [ coreutils slurp systemd util-linux wf-recorder recordingFinished ];
    text = builtins.readFile ./scripts/record.sh;
  };
in
{
  home.packages = lib.optionals pkgs.stdenv.isLinux [
    pkgs.cava
    pkgs.grim
    pkgs.slurp
    pkgs.wl-clipboard
    pkgs.wf-recorder
    screenshot
    recording
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
