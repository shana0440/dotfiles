# Opt-in by import in the desktop Linux Home Manager profile only.
{ pkgs, ... }:

{
  home.packages = [ (import ./package.nix { inherit pkgs; }) ];
}
