{ ... }:

{
  imports = [
    ./git/git.nix
    ./kitty/kitty.nix
    ./neovim/neovim.nix
    ./tmux/tmux.nix
    ./shell/shell.nix

    ./programs.nix
  ];

  home.username = "kwguo";
  home.homeDirectory = "/home/kwguo";

  # Compatibility baseline; do not change just to update packages.
  home.stateVersion = "26.05";

  # Make the Home Manager command available after the first activation.
  programs.home-manager.enable = true;
}
