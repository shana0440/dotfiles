# Install Quickshell and link its native configuration.
{ config, pkgs, ... }:

let
  playbackMonitor = pkgs.writeShellApplication {
    name = "pipewire-playback-monitor";
    runtimeInputs = [ pkgs.pipewire ];
    text = ''
      exec ${pkgs.python3}/bin/python3 -u ${./pipewire/playback_monitor.py}
    '';
  };
in
{
  home.packages = [ pkgs.quickshell pkgs.pipewire playbackMonitor ];

  xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink
    "${config.dotfiles.directory}/quickshell/config";
}
