# Desktop Linux Home Manager profile.
{ ... }:

{
  imports = [
    ./common.nix
    ./kitty/kitty.nix
    ./hyprland/hyprland.nix
  ];

  home.homeDirectory = "/home/kwguo";
}
