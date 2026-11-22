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
  chatClipboard = pkgs.writeShellApplication {
    name = "mei-chat-clipboard";
    runtimeInputs = [ pkgs.wl-clipboard ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./scripts/chat_clipboard.py} "$@"
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
  quickshellWithVideo = pkgs.symlinkJoin {
    name = "quickshell-with-video-${pkgs.quickshell.version}";
    paths = [ pkgs.quickshell ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for program in quickshell qs; do
        wrapProgram $out/bin/$program \
          --prefix QML_IMPORT_PATH : ${pkgs.qt6.qtmultimedia}/${pkgs.qt6.qtbase.qtQmlPrefix} \
          --prefix QT_PLUGIN_PATH : ${pkgs.qt6.qtmultimedia}/${pkgs.qt6.qtbase.qtPluginPrefix} \
          --set QT_FFMPEG_DECODING_HW_DEVICE_TYPES ""
      done
    '';
  };
  islandShader = pkgs.runCommand "island-goo.frag.qsb" {
    nativeBuildInputs = [ pkgs.qt6.qtshadertools ];
  } ''
    qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$out" ${./shaders/island_goo.frag}
  '';
in
{
  home.packages = [ quickshellWithVideo pkgs.pipewire playbackMonitor systemStatus launcherBadgeMonitor bluetoothAgent imagePicker linkPreview ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.cava
      pkgs.libnotify
      pkgs.wl-clipboard
      chatClipboard
    ];

  xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink
    "${config.dotfiles.directory}/quickshell/config";
  home.activation.publishIslandShader = publishShaderPathForLiveReload
    "${config.xdg.configHome}/quickshell-shaders/island-goo" islandShader;
}
