# Install Git and link its native configuration without generating Git settings.
{ config, pkgs, ... }:

let
  link = config.lib.file.mkOutOfStoreSymlink;
  gitDir = "${config.home.homeDirectory}/dotfiles/git";
in
{
  home.packages = [ pkgs.git ];

  xdg.configFile."git/config".source = link "${gitDir}/.gitconfig";
  home.file = {
    ".gitignore_global".source = link "${gitDir}/.gitignore_global";
    ".gitcommit.template".source = link "${gitDir}/.gitcommit.template";
  };
}
