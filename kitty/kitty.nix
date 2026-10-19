# Install Kitty and manage its native configuration through Home Manager.
{ config, pkgs, ... }:

{
  home.packages = [ pkgs.kitty ];

  xdg.configFile."kitty/kitty.conf".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles/kitty/kitty.conf";
}
