# Shared command-line tools managed by Home Manager on NixOS and macOS.
{ pkgs, ... }:

{
  programs.fzf.enable = true;

  home.packages = with pkgs; [
    curl
    gnumake # make: run build and configuration targets
    ripgrep # rg: fast recursive text search
  ];
}
