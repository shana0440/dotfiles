{ lib, pkgs, ... }:

{
  home.packages = [ (import ./package.nix { inherit pkgs; }) ];

  # Keep mimeapps.list writable; change only the dedicated XAPK association.
  home.activation.waydroidXapkHandler = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${pkgs.xdg-utils}/bin/xdg-mime default waydroid-xapk-install.desktop application/x-xapk
  '';
}
