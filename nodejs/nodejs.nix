# Shared Node.js and npm configuration.
{ config, pkgs, ... }:

{
  home.packages = [ pkgs.nodejs ];

  # Keep npm global installs out of the read-only Nix store.
  home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
  home.sessionPath = [
    "${config.home.profileDirectory}/bin"
    "${config.home.homeDirectory}/.npm-global/bin"
  ];
}
