# Home Manager settings shared by Linux, macOS, and WSL.
{ pkgs, ... }:

{
  imports = [
    ./git/git.nix
    ./neovim/neovim.nix
    ./nodejs/nodejs.nix
    ./tmux/tmux.nix
    ./shell/shell.nix
    ./programs.nix
  ];

  home.username = "kwguo";

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  # Compatibility baseline; do not change just to update packages.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
