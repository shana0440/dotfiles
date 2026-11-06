# Zen Browser beta, packaged by the community Zen flake.
{ pkgs, zen-browser, ... }:

{
  home.packages = [ zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta ];
}
