{ config, lib, pkgs, ... }:

{
  options.dotfiles.directory = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/dotfiles";
    description = "Absolute path to the writable dotfiles checkout.";
  };

  config = {
    home.username = "kwguo";

    home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

    nix = {
      package = pkgs.nix;
      settings.experimental-features = [ "nix-command" "flakes" ];
    };

    home.stateVersion = "26.05";

    programs.home-manager.enable = true;
  };
}
