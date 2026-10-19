# Desktop Linux Home Manager profile.
{ ... }:

{
  imports = [
    ./common.nix
    (import ./applications.nix).homeManager
    ./kitty/kitty.nix
    ./hyprland/hyprland.nix
  ];

  home.homeDirectory = "/home/kwguo";
}
