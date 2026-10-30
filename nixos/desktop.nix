# Hyprland desktop, login manager, and shell.
{ config, pkgs, ... }:

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

  programs.hyprland.enable = true;

  # Installs Quickshell; its UI configuration and autostart are separate.
  environment.systemPackages = with pkgs; [
    quickshell
    wl-clipboard
  ];
}
