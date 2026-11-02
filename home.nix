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
    ./gtk/gtk.nix
    ./vicinae/vicinae.nix
    ./thunar/thunar.nix
    ./waydroid/waydroid.nix
    ./hyprland/hyprland.nix
    ./quickshell/quickshell.nix
    ./agent-workspace/agent-workspace.nix
  ];

  home.homeDirectory = "/home/kwguo";
}
