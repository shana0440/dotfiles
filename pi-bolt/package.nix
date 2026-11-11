{ pkgs, inputs }:

let
  inherit (pkgs) lib stdenv;
  sources = {
    x86_64-linux = inputs.pi-bolt-linux-x64;
    aarch64-linux = inputs.pi-bolt-linux-arm64;
    aarch64-darwin = inputs.pi-bolt-darwin-arm64;
  };
  src = sources.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "pi-bolt";
  version = builtins.elemAt (lib.splitString " " (builtins.readFile "${src}/pi-bolt.txt")) 1;
  inherit src;

  nativeBuildInputs = lib.optionals stdenv.isLinux [ pkgs.autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.isLinux [
    pkgs.stdenv.cc.cc.lib
    pkgs.libxcb
  ];

  dontConfigure = true;
  dontBuild = true;
  # Bun's executable contains an embedded payload; do not strip it.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/pi-bolt" "$out/bin"
    cp -r . "$out/lib/pi-bolt/"
    chmod +x "$out/lib/pi-bolt/pi"
    ln -s "$out/lib/pi-bolt/pi" "$out/bin/pi"
    ln -s "$out/lib/pi-bolt/pi" "$out/bin/pi-bolt"
    runHook postInstall
  '';

  meta = {
    description = "Pi coding agent compiled ahead of time to a native executable";
    homepage = "https://github.com/opensec-git/Pi-Bolt";
    license = lib.licenses.mit;
    platforms = builtins.attrNames sources;
    mainProgram = "pi-bolt";
  };
}
