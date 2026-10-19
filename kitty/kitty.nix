# Install Kitty and manage its native configuration through Home Manager.
{ pkgs, ... }:

{
  home.packages = [ pkgs.kitty ];

  xdg.configFile."kitty/kitty.conf".source = ./kitty.conf;
}
