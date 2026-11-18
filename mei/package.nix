{ pkgs, src }:

let
  nodejs = pkgs.nodejs_24;
in
pkgs.stdenv.mkDerivation {
  pname = "mei";
  version = src.shortRev or "unstable";
  inherit src;

  npmDeps = pkgs.importNpmLock { npmRoot = src; };
  nativeBuildInputs = [ nodejs pkgs.importNpmLock.npmConfigHook pkgs.makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/mei"
    cp -r daemon prompts template node_modules package.json "$out/lib/mei/"
    makeWrapper ${nodejs}/bin/node "$out/bin/mei" --add-flags "$out/lib/mei/daemon/cli.ts"
    makeWrapper ${nodejs}/bin/node "$out/bin/mei-daemon" --add-flags "$out/lib/mei/daemon/main.ts"
    runHook postInstall
  '';

  meta = {
    description = "Personal assistant daemon driven by Pi-Bolt";
    homepage = "https://github.com/shana0440/mei";
    mainProgram = "mei";
  };
}
