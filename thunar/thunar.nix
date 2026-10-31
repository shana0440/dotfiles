{ lib, pkgs, ... }:

{
  home.packages = [ pkgs.thunar pkgs.xfconf ];

  # Update only the folder handler; other application associations remain user-managed.
  home.activation.thunarDefaultFileManager = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${pkgs.xdg-utils}/bin/xdg-mime default thunar.desktop inode/directory
  '';
}
