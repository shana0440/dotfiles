# macOS Home Manager profile (Apple Silicon or Intel).
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
    ./kitty/kitty.nix
  ];

  home.homeDirectory = "/Users/kwguo";
}
