{ config, pkgs, ... }:

let
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
  recording = pkgs.writeShellApplication {
    name = "screen-capture-record";
    runtimeInputs = with pkgs; [ coreutils slurp systemd util-linux wf-recorder quickshell recordingFinished ];
    text = builtins.readFile ./scripts/record.sh;
  };
  application = pkgs.writeShellApplication {
    name = "screen-capture";
    runtimeInputs = [ pkgs.coreutils pkgs.quickshell screenshot recording ];
    text = ''
      shell_config="''${XDG_CONFIG_HOME:-$HOME/.config}/screen-capture"
      # Reopening from a launcher addresses this application, never the bar.
      if timeout 2s quickshell --path "$shell_config" ipc call capture openMenu >/dev/null 2>&1; then
        exit 0
      fi
      exec quickshell --path "$shell_config" --no-duplicate --daemonize
    '';
  };
in
{
  home.packages = [ application screenshot recording ];

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
