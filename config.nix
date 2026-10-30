# Shared Home Manager settings and dotfiles options.
{ config, lib, pkgs, ... }:

{
  options.dotfiles.directory = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/dotfiles";
    description = "Absolute path to the writable dotfiles checkout.";
  };

  config = {
    home.username = "kwguo";

    nix = {
      package = pkgs.nix;
      settings.experimental-features = [ "nix-command" "flakes" ];
    };

    # Compatibility baseline; do not change just to update packages.
    home.stateVersion = "26.05";

    programs.home-manager.enable = true;
  };
}
