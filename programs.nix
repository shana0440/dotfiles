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

  home.shellAliases.docker = "podman";

  home.packages = with pkgs; [
    curl # curl: transfer data using URLs
    fd # fd: fast file and directory search
    gh # gh: GitHub command-line interface
    gnumake # make: run build and configuration targets
    podman # podman: manage containers without a daemon
    podman-compose # podman-compose: run Compose applications with Podman
    ripgrep # rg: fast recursive text search
  ];
}
