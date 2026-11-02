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
    runtimeInputs = with pkgs; [ coreutils slurp systemd util-linux wf-recorder quickshell recordingFinished ];
    text = builtins.readFile ./scripts/record.sh;
  };
  systemStatus = pkgs.writeShellApplication {
    name = "system-status-snapshot";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./scripts/system_status.py}
    '';
  };
  launcherBadgeMonitor = pkgs.writeShellApplication {
    name = "launcher-badge-monitor";
    text = ''
      exec ${pkgs.python3.withPackages (ps: [ ps.dbus-next ])}/bin/python3 -u ${./scripts/launcher_badges.py}
    '';
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
  home.packages = [ pkgs.quickshell pkgs.pipewire playbackMonitor systemStatus launcherBadgeMonitor ]
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
