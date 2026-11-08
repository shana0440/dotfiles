{ config, pkgs, ... }:

let
  launcher = pkgs.writeShellApplication {
    name = "iphone-webcam";
    runtimeInputs = [
      config.programs.obs-studio.finalPackage
      pkgs.qrencode
      pkgs.python3
    ];
    text = ''
      export IPHONE_WEBCAM_HELPER=${./iphone-webcam.py}
    '' + builtins.readFile ./iphone-webcam.sh;
  };
in
{
  # Safari on iPhone -> VDO.Ninja -> OBS Browser source -> virtual webcam.
  # NixOS configures v4l2loopback with exclusive_caps for browser compatibility.
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
    package = pkgs.obs-studio.override { browserSupport = true; };
  };

  environment.systemPackages = [
    launcher
    (pkgs.makeDesktopItem {
      name = "iphone-webcam";
      desktopName = "iPhone Webcam";
      comment = "Show a pairing QR in a terminal and run OBS until stopped";
      exec = "${launcher}/bin/iphone-webcam";
      icon = "obs";
      categories = [ "AudioVideo" "Video" ];
      terminal = true;
    })
  ];
}
