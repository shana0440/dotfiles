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
    nodejs
    curl
    fd
    gh
    gnumake
    gnupg
    podman
    podman-compose
    ripgrep
  ];
}
