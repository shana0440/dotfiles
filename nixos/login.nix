# Login manager: SDDM showing the Quickshell lock screen (quickshell/config/Login).
{ config, pkgs, ... }:

let
  wallpaper = "/var/lib/login-ui/wallpaper.jpg";
  quickshell = ../quickshell/config;
  # The shared screen imports ../Theme and ../Icons, so the theme mirrors the
  # Quickshell config's layout around SDDM's Main.qml.
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
  services.xserver.enable = true; # X11 greeter; Hyprland uses Wayland.
  services.displayManager = {
    sddm = {
      enable = true;
      theme = "login-ui";
      # SVG icons in the shared screen.
      extraPackages = [ pkgs.kdePackages.qtsvg ];
      # Same logical size as the session (2560x1440 at 1.5), so the screen
      # matches the lock.
      settings.General.GreeterEnvironment = "QT_SCREEN_SCALE_FACTORS=1.5";
    };
    autoLogin = {
      enable = true;
      user = config.user.name;
    };
    defaultSession = "hyprland";
  };

  environment.systemPackages = [ theme ];
  # The greeter runs before the session, so it only sees system fonts.
  fonts.packages = [ pkgs.inter pkgs.adwaita-fonts ];

  # The greeter cannot read ~: wallpaper-set keeps a copy of the desktop
  # wallpaper here (wallpaper/wallpaper.nix).
  systemd.tmpfiles.rules = [ "d /var/lib/login-ui 0755 ${config.user.name} users -" ];
}
