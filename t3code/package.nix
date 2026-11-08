{ pkgs }:

let
  version = "0.1.7";
  # Official desktop releases, pinned independently of the nixpkgs channel.
  releases = {
    x86_64-linux = {
      file = "T3-Code-${version}-x86_64.AppImage";
      hash = "sha256-+q7kCU3KEnYFeEChpFprLQDXQYr79XNfdadQO3dOY9E=";
    };
    aarch64-linux = {
      file = "T3-Code-${version}-arm64.AppImage";
      hash = "sha256-REW+/6z5baO+LIHCgCIgIOOyYjV54zZLEPROhL/R48I=";
    };
    x86_64-darwin = {
      file = "T3-Code-${version}-x64.zip";
      hash = "sha256-tBj9hCbfunldkJcFhv68Y9BuMAItL4nctCfnL/GY1D8=";
    };
    aarch64-darwin = {
      file = "T3-Code-${version}-arm64.zip";
      hash = "sha256-N6TwR0kLg+jX4OTtD47ZAzji0gNlXgopNiHyTBOSF6E=";
    };
  };
  release = releases.${pkgs.stdenv.hostPlatform.system};
  src = pkgs.fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/${release.file}";
    inherit (release) hash;
  };
  pname = "t3code";
  meta = {
    description = "Control surface for coding agents";
    homepage = "https://t3.codes/";
    license = pkgs.lib.licenses.mit;
    platforms = builtins.attrNames releases;
    mainProgram = "t3code-desktop";
  };
  appimageContents = pkgs.appimageTools.extractType2 {
    inherit pname version src;
  };
in
if pkgs.stdenv.hostPlatform.isLinux then
  pkgs.appimageTools.wrapType2 {
    inherit pname version src meta;
    # Bypass AppRun's Chromium flags when Electron runs the bundled CLI as Node.
    runScript = pkgs.writeShellScript "t3code-run" ''
      if [ "''${ELECTRON_RUN_AS_NODE:-}" = 1 ]; then
        exec ${appimageContents}/t3code "$@"
      fi
      exec ${appimageContents}/AppRun "$@"
    '';
    extraInstallCommands = ''
      mv "$out/bin/t3code" "$out/bin/t3code-desktop"
      install -Dm755 ${pkgs.writeShellScript "t3" ''
        export ELECTRON_RUN_AS_NODE=1
        exec "''${0%/*}/t3code-desktop" ${appimageContents}/resources/app.asar/apps/server/dist/bin.mjs "$@"
      ''} "$out/bin/t3"
      ln -s t3 "$out/bin/t3code"
      install -Dm644 ${appimageContents}/t3code.desktop "$out/share/applications/t3code.desktop"
      substituteInPlace "$out/share/applications/t3code.desktop" \
        --replace-fail 'Exec=AppRun' 'Exec=t3code-desktop'
      cp -r ${appimageContents}/usr/share/icons "$out/share/"
    '';
  }
else
  pkgs.stdenvNoCC.mkDerivation {
    inherit pname version src meta;
    nativeBuildInputs = [ pkgs.unzip pkgs.makeWrapper ];
    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications" "$out/bin"
      cp -R *.app "$out/Applications/"
      app=("$out/Applications/"*.app)
      makeWrapper "''${app[0]}/Contents/MacOS/"* "$out/bin/t3code-desktop"
      makeWrapper "''${app[0]}/Contents/MacOS/"* "$out/bin/t3" \
        --set ELECTRON_RUN_AS_NODE 1 \
        --add-flags "\"''${app[0]}/Contents/Resources/app.asar/apps/server/dist/bin.mjs\""
      ln -s t3 "$out/bin/t3code"
      runHook postInstall
    '';
  }
