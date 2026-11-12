{ pkgs, ... }:

let
  captureNotification = pkgs.writeShellApplication {
    name = "screen-capture-notify";
    runtimeInputs = with pkgs; [ coreutils ffmpeg libnotify ];
    text = builtins.readFile ./scripts/notify.sh;
  };
  snapshot = pkgs.writeShellApplication {
    name = "screen-capture-snapshot";
    runtimeInputs = with pkgs; [ grim hyprland wl-clipboard captureNotification ];
    text = ''
      exec ${pkgs.python3.withPackages (ps: [ ps.pillow ])}/bin/python3 ${./scripts/snapshot.py} "$@"
    '';
  };
  screenshot = pkgs.writeShellApplication {
    name = "screen-capture-screenshot";
    runtimeInputs = with pkgs; [ coreutils grim slurp wl-clipboard quickshell captureNotification ];
    text = builtins.readFile ./scripts/screenshot.sh;
  };
  recordingFinished = pkgs.writeShellApplication {
    name = "screen-capture-recording-finished";
    runtimeInputs = [ pkgs.coreutils captureNotification ];
    text = builtins.readFile ./scripts/recording_finished.sh;
  };
  windowRecording = pkgs.writeShellApplication {
    name = "screen-capture-window-record";
    runtimeInputs = with pkgs; [ grim ffmpeg ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./scripts/window_record.py} "$@"
    '';
  };
  recording = pkgs.writeShellApplication {
    name = "screen-capture-record";
    runtimeInputs = with pkgs; [ coreutils slurp systemd util-linux wf-recorder quickshell recordingFinished windowRecording ];
    text = builtins.readFile ./scripts/record.sh;
  };
in
{
  # Commands only; the capture UI lives in the Quickshell bar (quickshell/config/Capture).
  home.packages = [ screenshot recording snapshot captureNotification ];
}
