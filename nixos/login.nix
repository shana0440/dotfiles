{ config, pkgs, ... }:

let
  wallpaper = "/var/lib/login-ui/wallpaper.jpg";
  quickshell = ../quickshell/config;
  copyWallpaper = pkgs.writeShellApplication {
    name = "login-wallpaper-copy";
    runtimeInputs = [ pkgs.imagemagick pkgs.ffmpeg-headless pkgs.coreutils ];
    text = ''
      current="''${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper/current"
      [ -s "$current" ] || exit 0
      image="$(head -n 1 "$current")"
      [ -f "$image" ] || { echo "login-wallpaper: $image is gone" >&2; exit 0; }
      temp="$(mktemp -p "$(dirname ${wallpaper})" .wallpaper.XXXXXX)"
      trap 'rm -f "$temp"' EXIT
      case "''${image,,}" in
        *.mp4 | *.webm | *.mkv | *.mov)
          frame="$(mktemp -p "$(dirname ${wallpaper})" .wallpaper-frame.XXXXXX.png)"
          trap 'rm -f "$temp" "$frame"' EXIT
          ffmpeg -v error -y -i "$image" -frames:v 1 "$frame"
          image="$frame"
          ;;
      esac
      magick "''${image}[0]" -auto-orient -resize "2560x1440^" -strip -quality 90 "jpg:$temp"
      chmod 644 "$temp"
      mv -f "$temp" ${wallpaper}
    '';
  };
  greeter = pkgs.runCommand "login-ui-greeter" { } ''
    mkdir -p $out/Icons
    cp ${./greeter/shell.qml} $out/shell.qml
    cp -r ${quickshell}/Login $out/Login
    cp -r ${quickshell}/Theme $out/Theme
    cp -r ${quickshell}/Icons/lucide $out/Icons/lucide
    chmod -R u+w $out
    rm -r $out/Login/tests
  '';
  startHyprland = "${config.programs.hyprland.package}/bin/start-hyprland";
  showGreeter = pkgs.writeShellScript "login-ui-greeter" ''
    export LOGIN_USER=${config.user.name}
    export LOGIN_SESSION_COMMAND=${startHyprland}
    export LOGIN_WALLPAPER=${wallpaper}
    export QT_SCALE_FACTOR=1.5
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    exec ${pkgs.cage}/bin/cage -s -- ${pkgs.quickshell}/bin/quickshell --path ${greeter}
  '';
in
{
  services.greetd = {
    enable = true;
    settings.default_session.command = "${showGreeter}";
  };

  systemd.user.services.login-keyring-default = {
    description = "Use the Login keyring as the default Secret Service collection";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    unitConfig.ConditionUser = config.user.name;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/busctl --user --timeout=10s call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.Secret.Service SetAlias so default /org/freedesktop/secrets/collection/login";
    };
  };

  fonts.packages = [ pkgs.inter pkgs.adwaita-fonts ];

  systemd.tmpfiles.rules = [ "d /var/lib/login-ui 0755 ${config.user.name} users -" ];

  systemd.user.paths.login-wallpaper = {
    wantedBy = [ "default.target" ];
    unitConfig.ConditionUser = config.user.name;
    pathConfig.PathChanged = "%h/.local/state/wallpaper/current";
  };
  systemd.user.services.login-wallpaper = {
    description = "Copy the desktop wallpaper for the login screen";
    wantedBy = [ "default.target" ];
    unitConfig.ConditionUser = config.user.name;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${copyWallpaper}/bin/login-wallpaper-copy";
    };
  };
}
