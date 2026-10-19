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

  programs.hyprland.enable = true;

  # Installs Quickshell; its UI configuration and autostart are separate.
  environment.systemPackages = with pkgs; [
    quickshell
    wl-clipboard
  ];
}
