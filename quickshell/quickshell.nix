{ config, lib, pkgs, ... }:

let
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
      pkgs.wl-clipboard
    ];

  xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink
    "${config.dotfiles.directory}/quickshell/config";
}
