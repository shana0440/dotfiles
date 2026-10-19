# Install Git and link its native configuration without generating Git settings.
{ pkgs, ... }:

{
  home.packages = [ pkgs.git ];

  xdg.configFile."git/config".source = ./.gitconfig;
  home.file = {
    ".gitignore_global".source = ./.gitignore_global;
    ".gitcommit.template".source = ./.gitcommit.template;
  };
}
