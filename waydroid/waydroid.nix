{ lib, pkgs, ... }:

{
  home.packages = [ (import ./package.nix { inherit pkgs; }) ];

  xdg.desktopEntries.waydroid = {
    name = "Waydroid";
    comment = "Open the Android desktop";
    exec = "/run/current-system/sw/bin/waydroid show-full-ui";
    icon = "/run/current-system/sw/share/icons/hicolor/512x512/apps/waydroid.png";
    terminal = false;
    categories = [ "System" "Emulator" ];
  };

  # Keep mimeapps.list writable; change only the dedicated XAPK association.
  home.activation.waydroidXapkHandler = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${pkgs.xdg-utils}/bin/xdg-mime default waydroid-xapk-install.desktop application/x-xapk
  '';
}
