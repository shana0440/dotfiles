{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "waydroid-houdini";
  version = "13.0.1";
  src = fetchFromGitHub {
    owner = "supremegamers";
    repo = "vendor_intel_proprietary_houdini";
    rev = "740353bf4391969902bc80ee2a9258db18481b45";
    hash = "sha256-2+US+XF85b2F118P535796RS13zHhs/CQBfuukCAQWI=";
  };

  dontConfigure = true;
  dontBuild = true;
  # These are Android binaries, not host programs: preserve their ELF interpreters.
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/system" "$out/share/doc/waydroid-houdini"
    cp -R prebuilts/. "$out/system/"
    cp README.md "$out/share/doc/waydroid-houdini/"
    find "$out/system" -type d -exec chmod 0755 {} +
    find "$out/system" -type f -exec chmod 0644 {} +
    find "$out/system/bin" -type f -exec chmod 0755 {} +
    # The upstream Android.mk installs these under /vendor; our layer uses /system.
    substituteInPlace "$out/system/etc/init/houdini.rc" \
      --replace-fail '/vendor/etc/binfmt_misc/' '/system/etc/binfmt_misc/'
    runHook postInstall
  '';

  meta = {
    description = "Android 13 ARM/ARM64 translation payload for Intel Waydroid hosts";
    homepage = "https://github.com/supremegamers/vendor_intel_proprietary_houdini";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
