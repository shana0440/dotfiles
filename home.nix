# Desktop Linux Home Manager profile.
{ ... }:

{
  imports = [
    ./config.nix
    ./git/git.nix
    ./neovim/neovim.nix
    ./nodejs/nodejs.nix
    ./tmux/tmux.nix
    ./shell/shell.nix
    ./programs.nix
    (import ./applications.nix).homeManager
    ./kitty/kitty.nix
    ./hyprland/hyprland.nix
  ];

  home.homeDirectory = "/home/kwguo";
}
