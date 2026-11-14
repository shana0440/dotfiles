# Hyprland desktop. The login manager is in login.nix.
{ config, ... }:

{
  # RTX 3070 (Ampere): use NVIDIA's open kernel modules with its userspace driver.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  programs.hyprland.enable = true;
  # Includes PAM integration for unlocking the session.
  programs.hyprlock.enable = true;
}
