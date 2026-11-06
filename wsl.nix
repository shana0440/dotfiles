# WSL Home Manager profile: shared CLI tools, no desktop modules.
{ ... }:

{
  imports = [
    ./config.nix
    ./git/git.nix
    ./neovim/neovim.nix
    ./nodejs/nodejs.nix
    ./agents.nix
    ./tmux/tmux.nix
    ./shell/shell.nix
    ./programs.nix
  ];

  home.homeDirectory = "/home/kwguo";
}
