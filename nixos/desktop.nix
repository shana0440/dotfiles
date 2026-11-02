# Hyprland desktop and login manager.
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

  # RTX 3070 (Ampere): use NVIDIA's open kernel modules with its userspace driver.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Android container runtime; initialize its images separately after activation.
  virtualisation.waydroid.enable = true;

  programs.hyprland.enable = true;
  # Includes PAM integration for unlocking the session.
  programs.hyprlock.enable = true;

}
