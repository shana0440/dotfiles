# Login manager.
{ config, ... }:

{
  services.xserver.enable = true; # X11 greeter; Hyprland uses Wayland.
  services.displayManager = {
    sddm.enable = true;
    autoLogin = {
      enable = true;
      user = config.user.name;
    };
    defaultSession = "hyprland";
  };

  # The greeter cannot read ~: wallpaper-set keeps a copy of the desktop
  # wallpaper here (wallpaper/wallpaper.nix).
  systemd.tmpfiles.rules = [ "d /var/lib/login-ui 0755 ${config.user.name} users -" ];
}
