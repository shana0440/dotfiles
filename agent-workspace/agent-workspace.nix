# A clean, on-demand X11 workspace; no personal desktop configuration or startup apps.
{ pkgs, ... }:

{
  home.packages = [ (import ./package.nix { inherit pkgs; }) ];
}
