{ config, pkgs, ... }:

let
  # NVIDIA-only host: keep rendering overrides separate from Waydroid-owned image metadata.
  properties = (pkgs.formats.ini { }).generate "waydroid-properties.ini" {
    properties = {
      "ro.hardware.gralloc" = "default";
      "ro.hardware.egl" = "swiftshader";
    };
  };
in
{
  virtualisation.waydroid = {
    enable = true;
    # Avoid legacy ip_tables, which is absent from this host's running module tree.
    package = pkgs.waydroid-nftables;
  };

  xdg.mime.defaultApplications."application/vnd.android.package-archive" =
    "waydroid.app.install.desktop";

  systemd.services.waydroid-container = {
    serviceConfig.StateDirectory = "waydroid";
    # Run while the container is stopped, before its D-Bus service accepts requests.
    # Seed properties before first initialization; preserve an existing image selection.
    preStart = ''
      ${pkgs.crudini}/bin/crudini --merge /var/lib/waydroid/waydroid.cfg < ${properties}
      if [ -d /var/lib/waydroid/rootfs ]; then
        ${config.virtualisation.waydroid.package}/bin/waydroid upgrade -o
      fi
    '';
  };
}
