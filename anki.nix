# Anki and its Nix-managed add-ons; keep existing profiles and decks writable.
{ pkgs, ... }:

{
  home.packages = [
    (pkgs.anki.withAddons [
      (pkgs.ankiAddons.anki-connect.withConfig {
        config = {
          webBindAddress = "127.0.0.1";
          webBindPort = 8765;
          webCorsOriginList = [ "http://localhost" ];
        };
      })
    ])
  ];
}
