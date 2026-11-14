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
}
