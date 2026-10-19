# Desktop applications managed by NixOS.
{ pkgs, ... }:

{
  # Required for proprietary applications such as Discord and Steam.
  nixpkgs.config.allowUnfree = true;

  programs.firefox.enable = true;
  programs.steam.enable = true;

  environment.systemPackages = with pkgs; [
    kitty
    discord
    bitwarden-desktop
    telegram-desktop
    signal-desktop
    anki
  ];

}
