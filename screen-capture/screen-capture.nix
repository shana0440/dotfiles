{ config, pkgs, ... }:

let
  snapshot = pkgs.writeShellApplication {
    name = "screen-capture-snapshot";
    runtimeInputs = with pkgs; [ grim hyprland wl-clipboard ];
    text = ''
      exec ${pkgs.python3.withPackages (ps: [ ps.pillow ])}/bin/python3 ${./scripts/snapshot.py} "$@"
    '';
  };
  screenshot = pkgs.writeShellApplication {
    name = "screen-capture-screenshot";
    runtimeInputs = with pkgs; [ coreutils grim slurp wl-clipboard quickshell ];
    text = builtins.readFile ./scripts/screenshot.sh;
  };
  recordingFinished = pkgs.writeShellApplication {
    name = "screen-capture-recording-finished";
    runtimeInputs = [ pkgs.coreutils ];
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
  application = pkgs.writeShellApplication {
    name = "screen-capture";
    runtimeInputs = [ pkgs.coreutils pkgs.quickshell screenshot recording snapshot ];
    text = ''
      shell_config="''${XDG_CONFIG_HOME:-$HOME/.config}/screen-capture"
      background=0
      hide_stop=false
      for argument in "$@"; do
        case "$argument" in
          --background)
            # Preload QML without showing or freezing the desktop.
            export SCREEN_CAPTURE_BACKGROUND=1
            background=1
            ;;
          --no-stop-toolbar)
            # The bar shows recording state and Stop; hide our floating control.
            # Passed with each open request; the env covers a fresh start.
            export SCREEN_CAPTURE_HIDE_STOP_TOOLBAR=1
            hide_stop=true
            ;;
          *)
            printf 'Usage: screen-capture [--background] [--no-stop-toolbar]\n' >&2
            exit 2
            ;;
        esac
      done
      if [ "$background" = 0 ]; then
        # Reopening from a launcher addresses this application, never the bar.
        if timeout 2s quickshell --path "$shell_config" ipc call capture openMenu "$hide_stop" >/dev/null 2>&1; then
          exit 0
        fi
      fi
      exec quickshell --path "$shell_config" --no-duplicate --daemonize
    '';
  };
in
{
  home.packages = [ application screenshot recording snapshot ];

  xdg.configFile."screen-capture".source = config.lib.file.mkOutOfStoreSymlink
    "${config.dotfiles.directory}/screen-capture/config";

  xdg.desktopEntries.screen-capture = {
    name = "Screen Capture";
    genericName = "Screenshot and Screen Recorder";
    comment = "Capture your screen or a selected region";
    exec = "${application}/bin/screen-capture";
    icon = "camera-photo";
    terminal = false;
    categories = [ "Utility" "AudioVideo" "Recorder" ];
    startupNotify = false;
  };
}
