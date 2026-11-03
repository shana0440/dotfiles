{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "waydroid-ndk-translation";
  version = "0.2.3";
  src = fetchFromGitHub {
    owner = "supremegamers";
    repo = "vendor_google_proprietary_ndk_translation-prebuilt";
    rev = "68734c52556d3d7a6db34c603dd9276915c29f2f";
    hash = "sha256-hYpCOuyL/XkjONU7KfE6CU+14jbSzp9JBc8NmET6jXw=";
  };

  dontConfigure = true;
  dontBuild = true;
  # These are Android binaries, not host programs: preserve their ELF interpreters.
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/system" "$out/share/doc/waydroid-ndk-translation"
    cp -R prebuilts/. "$out/system/"
    cp README.md ARM_TO_AMD_DBT_LICENSE.txt "$out/share/doc/waydroid-ndk-translation/"
    find "$out/system" -type d -exec chmod 0755 {} +
    find "$out/system" -type f -exec chmod 0644 {} +
    find "$out/system/bin" -type f -exec chmod 0755 {} +
    runHook postInstall
  '';

  meta = {
    description = "Android 13 ARM/ARM64 ndk_translation payload for Waydroid";
    homepage = "https://github.com/supremegamers/vendor_google_proprietary_ndk_translation-prebuilt";
    # The bundled ARM license notice restricts use/redistribution to AMD CPUs.
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
