# User applications managed by standalone Home Manager.
{ pkgs, ... }:

{
  # Required for proprietary applications such as Discord.
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    firefox
    discord
    bitwarden-desktop
    telegram-desktop
    signal-desktop
    anki
  ];

  # Steam belongs in /etc/nixos/configuration.nix:
  # programs.steam.enable = true;
}
