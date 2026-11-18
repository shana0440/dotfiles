{ config, lib, pkgs, ... }:

let
  publishShaderPathForLiveReload = import ./publish-shader-path.nix { inherit lib; };
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
  imagePicker = pkgs.writeShellApplication {
    name = "pick-image";
    text = ''
      exec ${pkgs.python3.withPackages (ps: [ ps.dbus-next ])}/bin/python3 -u ${./scripts/pick_image.py} "$@"
    '';
  };
  linkPreview = pkgs.writeShellApplication {
    name = "link-preview";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./scripts/link_preview.py} "$@"
    '';
  };
  playbackMonitor = pkgs.writeShellApplication {
    name = "pipewire-playback-monitor";
    runtimeInputs = [ pkgs.pipewire ];
    text = ''
      exec ${pkgs.python3}/bin/python3 -u ${./pipewire/playback_monitor.py}
    '';
  };
  islandShader = pkgs.runCommand "island-goo.frag.qsb" {
    nativeBuildInputs = [ pkgs.qt6.qtshadertools ];
  } ''
    qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$out" ${./shaders/island_goo.frag}
  '';
in
{
  home.packages = [ pkgs.quickshell pkgs.pipewire playbackMonitor systemStatus launcherBadgeMonitor bluetoothAgent imagePicker linkPreview ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.cava
      pkgs.libnotify
      pkgs.wl-clipboard
    ];

  xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink
    "${config.dotfiles.directory}/quickshell/config";
  home.activation.publishIslandShader = publishShaderPathForLiveReload
    "${config.xdg.configHome}/quickshell-shaders/island-goo" islandShader;
}
