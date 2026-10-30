# Install Quickshell and link its native configuration.
{ config, pkgs, ... }:

{
  home.packages = [ pkgs.quickshell ];

  xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink
    "${config.dotfiles.directory}/quickshell/config";
}
