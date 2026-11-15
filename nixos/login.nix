{ config, pkgs, ... }:

let
  wallpaper = "/var/lib/login-ui/wallpaper.jpg";
  quickshell = ../quickshell/config;
  copyWallpaper = pkgs.writeShellApplication {
    name = "login-wallpaper-copy";
    runtimeInputs = [ pkgs.imagemagick pkgs.coreutils ];
    text = ''
      current="''${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper/current"
      [ -s "$current" ] || exit 0
      image="$(head -n 1 "$current")"
      [ -f "$image" ] || { echo "login-wallpaper: $image is gone" >&2; exit 0; }
      temp="$(mktemp -p "$(dirname ${wallpaper})" .wallpaper.XXXXXX)"
      trap 'rm -f "$temp"' EXIT
      magick "''${image}[0]" -auto-orient -resize "2560x1440^" -strip -quality 90 "jpg:$temp"
      chmod 644 "$temp"
      mv -f "$temp" ${wallpaper}
    '';
  };
  theme = pkgs.runCommand "login-ui-sddm-theme" { } ''
    dir=$out/share/sddm/themes/login-ui
    mkdir -p $dir/Icons
    cp ${./sddm-theme}/* $dir/
    cp -r ${quickshell}/Login $dir/Login
    cp -r ${quickshell}/Theme $dir/Theme
    cp -r ${quickshell}/Icons/lucide $dir/Icons/lucide
    chmod -R u+w $dir
    rm -r $dir/Login/tests
    cat > $dir/theme.conf <<EOF
    [General]
    background=${wallpaper}
    EOF
  '';
in
{
  services.xserver.enable = true;
  services.displayManager = {
    sddm = {
      enable = true;
      theme = "login-ui";
      extraPackages = [ pkgs.kdePackages.qtsvg ];
      settings.General.GreeterEnvironment = "QT_SCREEN_SCALE_FACTORS=1.5";
    };
    autoLogin = {
      enable = true;
      user = config.user.name;
    };
    defaultSession = "hyprland";
  };

  environment.systemPackages = [ theme ];
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
