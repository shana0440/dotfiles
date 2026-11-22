{ lib, fetchurl, linkFarm, writeShellApplication, eagle }:

let
  version = "0.8.0";
  plugin = fetchurl {
    url = "https://github.com/tuki0918/eagle-media-preview-server/releases/download/v${version}/Media.Preview.Server.eagleplugin";
    hash = "sha256-4wEzjpORZzFlkcW1ZVSyAwt2u0g+uzGUejuvTwjjyrc=";
  };
  installer = linkFarm "eagle-media-preview-${version}" [
    { name = "Media Preview Server.eagleplugin"; path = plugin; }
  ];
in
writeShellApplication {
  name = "eagle-media-preview-install";
  text = ''
    exec ${lib.getExe eagle} "${installer}/Media Preview Server.eagleplugin"
  '';
  meta = {
    description = "Open the pinned Media Preview Server plugin in Eagle for installation";
    homepage = "https://github.com/tuki0918/eagle-media-preview-server";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
