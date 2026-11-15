{ pkgs, ... }:

{
  programs.fzf.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
  };

  home.shellAliases.docker = "podman";

  home.packages = with pkgs; [
    curl
    fd
    gh
    gnumake
    podman
    podman-compose
    ripgrep
  ];
}
