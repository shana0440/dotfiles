# Shared command-line tools managed by Home Manager on NixOS and macOS.
{ pkgs, ... }:

{
  programs.fzf.enable = true; # fzf: interactive fuzzy finder

  # direnv: automatically load and unload project environments
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
  };

  home.packages = with pkgs; [
    curl # curl: transfer data using URLs
    fd # fd: fast file and directory search
    gnumake # make: run build and configuration targets
    ripgrep # rg: fast recursive text search
  ];
}
