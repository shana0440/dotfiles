{ pkgs }:

let
  python = pkgs.python3.withPackages (ps: [ ps.dbus-python ]);
  launcher = pkgs.writeShellApplication {
    name = "waydroid-xapk-install";
    runtimeInputs = [ pkgs.android-tools pkgs.iproute2 pkgs.zenity ];
    text = ''
      exec ${python}/bin/python3 ${./install_xapk.py} "$@"
    '';
  };
  desktop = pkgs.makeDesktopItem {
    name = "waydroid-xapk-install";
    desktopName = "Install XAPK in Waydroid";
    comment = "Install an XAPK's APK splits together, starting Waydroid if needed";
    exec = "${launcher}/bin/waydroid-xapk-install %f";
    icon = "waydroid";
    mimeTypes = [ "application/x-xapk" ];
    categories = [ "Utility" ];
    noDisplay = true;
  };
  mime = pkgs.writeTextFile {
    name = "waydroid-xapk-mime";
    destination = "/share/mime/packages/waydroid-xapk.xml";
    text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
        <mime-type type="application/x-xapk">
          <comment>XAPK Android application bundle</comment>
          <sub-class-of type="application/zip"/>
          <glob pattern="*.xapk" weight="80"/>
        </mime-type>
      </mime-info>
    '';
  };
in
pkgs.symlinkJoin {
  name = "waydroid-xapk-installer";
  paths = [ launcher desktop mime ];
  meta.mainProgram = "waydroid-xapk-install";
}
