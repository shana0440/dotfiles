# Desktop Linux Home Manager profile.
{ ... }:

{
  imports = [
    ./config.nix
    ./git/git.nix
    ./neovim/neovim.nix
    ./nodejs/nodejs.nix
    ./agents/agents.nix
    ./tmux/tmux.nix
    ./shell/shell.nix
    ./programs.nix
    (import ./applications.nix).homeManager
    ./anki.nix
    ./moshi.nix
    ./zen.nix
    (import ./vpn/vpn.nix).homeManager
    ./kitty/kitty.nix
    ./fonts/fonts.nix
    ./gtk/gtk.nix
    ./vicinae/vicinae.nix
    (import ./file-manager/file-manager.nix).homeManager
    ./hyprland/hyprland.nix
    ./wallpaper/wallpaper.nix
    ./quickshell/quickshell.nix
    ./screen-capture/screen-capture.nix
    ./agent-workspace/agent-workspace.nix
  ];

  home.homeDirectory = "/home/kwguo";
}
