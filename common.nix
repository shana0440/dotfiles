# Home Manager settings shared by Linux, macOS, and WSL.
{ ... }:

{
  imports = [
    ./git/git.nix
    ./neovim/neovim.nix
    ./tmux/tmux.nix
    ./shell/shell.nix
    ./programs.nix
  ];

  home.username = "kwguo";

  # Compatibility baseline; do not change just to update packages.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
