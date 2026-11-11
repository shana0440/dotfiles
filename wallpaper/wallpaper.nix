{ ... }:

{
  # Installs the client and runs the daemon as a user service.
  # Hyprland explicitly starts it because this session does not activate
  # graphical-session.target (see hyprland/hyprland.lua).
  services.awww.enable = true;
}
