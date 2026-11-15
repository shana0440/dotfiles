{ ... }:

{
  imports = [
    ./config.nix
    ./git/git.nix
    ./neovim/neovim.nix
    ./agents/agents.nix
    ./tmux/tmux.nix
    ./shell/shell.nix
    ./programs.nix
  ];

  home.homeDirectory = "/home/kwguo";
}
