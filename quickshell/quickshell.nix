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
  bluetoothAgent = pkgs.writeShellApplication {
    name = "bluetooth-pairing-agent";
    text = ''
      exec ${pkgs.python3.withPackages (ps: [ ps.dbus-next ])}/bin/python3 -u ${./scripts/bluetooth_agent.py}
    '';
  };
  playbackMonitor = pkgs.writeShellApplication {
    name = "pipewire-playback-monitor";
    runtimeInputs = [ pkgs.pipewire ];
    text = ''
      exec ${pkgs.python3}/bin/python3 -u ${./pipewire/playback_monitor.py}
    '';
  };
  # The bar's liquid island surface (see config/Components/IslandGoo.qml).
  islandShader = pkgs.runCommand "island-goo.frag.qsb" {
    nativeBuildInputs = [ pkgs.qt6.qtshadertools ];
  } ''
    qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$out" ${./shaders/island_goo.frag}
  '';
in
{
  home.packages = [ pkgs.quickshell pkgs.pipewire playbackMonitor systemStatus launcherBadgeMonitor bluetoothAgent ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.cava
      pkgs.wl-clipboard
    ];

  xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink
    "${config.dotfiles.directory}/quickshell/config";
  # The config is an out-of-store symlink, so the compiled shader's store path is
  # published beside it. The path changes with the shader, which also defeats Qt's
  # per-URL shader cache.
  xdg.configFile."quickshell-shaders/island-goo".text = "${islandShader}\n";
}
