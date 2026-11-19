{ inputs, lib, pkgs, ... }:

let
  platform = pkgs.stdenv.hostPlatform;
  spicePkgs = inputs.spicetify-nix.legacyPackages.${platform.system};
in {
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = lib.meta.availableOn platform pkgs.spotify;
    enabledCustomApps = [ spicePkgs.apps.marketplace ];
    theme = {
      name = "marketplace";
      src = pkgs.writeTextDir "color.ini" "[Marketplace]\n";
    };
  };
}
