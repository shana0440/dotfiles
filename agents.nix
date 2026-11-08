# Shared coding-agent tools, managed by Nix rather than npm global installs.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (import ./t3code/package.nix { inherit pkgs; })
    pi-coding-agent
  ];
}
