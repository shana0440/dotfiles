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
    ./fonts/fonts.nix
    ./vicinae/vicinae.nix
    ./hyprland/hyprland.nix
    ./quickshell/quickshell.nix
  ];

  home.homeDirectory = "/home/kwguo";
}
