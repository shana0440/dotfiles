# macOS Home Manager profile (Apple Silicon or Intel).
{ ... }:

{
  imports = [
    ./common.nix
    ./kitty/kitty.nix
  ];

  home.homeDirectory = "/Users/kwguo";
}
