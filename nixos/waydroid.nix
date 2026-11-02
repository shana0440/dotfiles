{ config, pkgs, ... }:

let
  # This host uses Android 13. Set false to stop advertising ARM support.
  armTranslation = true;
  # Trial libndk instead of Houdini, which stalls during Fate/GO startup.
  nativeBridge = pkgs.callPackage ./waydroid/ndk-translation.nix { };
  waydroid = if armTranslation then pkgs.waydroid-nftables.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./waydroid/native-bridge.patch ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace tools/helpers/images.py \
        --replace-fail '@nativeBridge@' '${nativeBridge}'
    '';
    passthru = (old.passthru or { }) // { inherit nativeBridge; };
  }) else pkgs.waydroid-nftables;

  # Keep host-specific properties separate from Waydroid-owned image metadata.
  properties = (pkgs.formats.ini { }).generate "waydroid-properties.ini" {
    properties = {
      "ro.hardware.gralloc" = "default";
      "ro.hardware.egl" = "swiftshader";
      "ro.product.cpu.abilist" = if armTranslation then "x86_64,x86,arm64-v8a,armeabi-v7a,armeabi" else "x86_64,x86";
      "ro.product.cpu.abilist32" = if armTranslation then "x86,armeabi-v7a,armeabi" else "x86";
      "ro.product.cpu.abilist64" = if armTranslation then "x86_64,arm64-v8a" else "x86_64";
      "ro.dalvik.vm.native.bridge" = if armTranslation then "libndk_translation.so" else "0";
      "ro.enable.native.bridge.exec" = if armTranslation then "1" else "0";
      "ro.enable.native.bridge.exec64" = if armTranslation then "1" else "0";
      "ro.vendor.enable.native.bridge.exec" = if armTranslation then "1" else "0";
      "ro.vendor.enable.native.bridge.exec64" = if armTranslation then "1" else "0";
      "ro.ndk_translation.version" = if armTranslation then nativeBridge.version else "";
      "ro.dalvik.vm.isa.arm" = if armTranslation then "x86" else "";
      "ro.dalvik.vm.isa.arm64" = if armTranslation then "x86_64" else "";
    };
  };
in
{
  virtualisation.waydroid = {
    enable = true;
    # Avoid legacy ip_tables, which is absent from this host's running module tree.
    package = waydroid;
  };

  assertions = [{
    assertion = !armTranslation || pkgs.stdenv.hostPlatform.system == "x86_64-linux";
    message = "This Waydroid ARM translation payload requires an x86_64 Linux host.";
  }];

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
