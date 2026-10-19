# Shared npm configuration; Node.js installation is managed separately.
{ config, ... }:

{
  # Keep npm global installs out of the read-only Nix store.
  home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.local";
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
}
