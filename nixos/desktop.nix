# Hyprland desktop, login manager, and shell.
{ pkgs, ... }:

{
  services.xserver.enable = true; # X11 greeter; Hyprland uses Wayland.
  services.displayManager = {
    sddm.enable = true;
    autoLogin = {
      enable = true;
      user = "kwguo";
    };
    defaultSession = "hyprland";
  };

  programs.hyprland.enable = true;

  # Installs Quickshell; its UI configuration and autostart are separate.
  environment.systemPackages = with pkgs; [
    quickshell
  ];
}
