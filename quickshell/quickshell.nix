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
  playbackMonitor = pkgs.writeShellApplication {
    name = "pipewire-playback-monitor";
    runtimeInputs = [ pkgs.pipewire ];
    text = ''
      exec ${pkgs.python3}/bin/python3 -u ${./pipewire/playback_monitor.py}
    '';
  };
in
{
  home.packages = [ pkgs.quickshell pkgs.pipewire playbackMonitor ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.cava
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      pkgs.wf-recorder
      screenshot
      recording
    ];

  xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink
    "${config.dotfiles.directory}/quickshell/config";
}
