{ pkgs, inputs }:

let
  inherit (pkgs) lib stdenv;
  system = stdenv.hostPlatform.system;
  target =
    {
      x86_64-linux = "linux-x86_64";
      aarch64-linux = "linux-aarch64";
      x86_64-darwin = "macos-x86_64";
      aarch64-darwin = "macos-aarch64";
    }
    .${system};
  appRelease = builtins.fromJSON (builtins.readFile inputs.herdr-app-release);
  coreRelease = builtins.fromJSON (builtins.readFile inputs.herdr-core-release);
  source =
    release:
    pkgs.fetchurl {
      inherit (release.targets.${target}) url sha256;
    };
  herdr-core = stdenv.mkDerivation {
    pname = "herdr-core";
    version = coreRelease.version;
    src = source coreRelease;
    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 herdr-core "$out/bin/herdr-core"
      ln -s herdr-core "$out/bin/hc"
      install -Dm644 LICENSE "$out/share/licenses/herdr-core/LICENSE"
      install -Dm644 THIRD-PARTY-NOTICES "$out/share/licenses/herdr-core/THIRD-PARTY-NOTICES"
      runHook postInstall
    '';
    meta = {
      description = "Persistent terminals for coding agents";
      homepage = "https://github.com/herdrdev/herdr-core";
      license = lib.licenses.asl20;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      mainProgram = "hc";
    };
  };
  herdr-app = stdenv.mkDerivation {
    pname = "herdr-app";
    version = appRelease.version;
    src = source appRelease;
    nativeBuildInputs = [ pkgs.makeWrapper ] ++ lib.optionals stdenv.isLinux [ pkgs.autoPatchelfHook ];
    buildInputs = lib.optionals stdenv.isLinux [
      pkgs.stdenv.cc.cc.lib
      pkgs.libxkbcommon
      pkgs.wayland
      pkgs.libX11
      pkgs.libXcursor
      pkgs.libXi
      pkgs.libXrandr
      pkgs.vulkan-loader
      pkgs.fontconfig
    ];
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
    ''
    + lib.optionalString stdenv.isLinux ''
      mkdir -p "$out/lib/herdr-app"
      cp -r . "$out/lib/herdr-app/"
      install -Dm644 herdr-app.svg "$out/share/icons/hicolor/scalable/apps/herdr-app.svg"
      makeWrapper "$out/lib/herdr-app/herdr-app" "$out/bin/herdr-app" \
        --prefix PATH : ${lib.makeBinPath [ herdr-core ]} \
        --prefix LD_LIBRARY_PATH : ${
          lib.makeLibraryPath [
            pkgs.vulkan-loader
            pkgs.wayland
            pkgs.libxkbcommon
            pkgs.libX11
            pkgs.libXcursor
            pkgs.libXi
            pkgs.libXrandr
            pkgs.fontconfig
          ]
        }
      install -Dm644 ${
        pkgs.makeDesktopItem {
          name = "herdr-app";
          desktopName = "Herdr";
          comment = "Terminals and coding agents that keep running";
          exec = "herdr-app";
          icon = "herdr-app";
          categories = [
            "Development"
            "TerminalEmulator"
          ];
          startupWMClass = "herdr-app";
        }
      }/share/applications/herdr-app.desktop "$out/share/applications/herdr-app.desktop"
    ''
    + lib.optionalString stdenv.isDarwin ''
      mkdir -p "$out/Applications/Herdr.app"
      cp -r . "$out/Applications/Herdr.app/"
      makeWrapper "$out/Applications/Herdr.app/Contents/MacOS/Herdr" "$out/bin/herdr-app" \
        --prefix PATH : ${lib.makeBinPath [ herdr-core ]}
    ''
    + ''
      runHook postInstall
    '';
    meta = {
      description = "Desktop terminals and coding agents backed by herdr-core";
      homepage = "https://github.com/herdrdev/herdr-app";
      license = lib.licenses.asl20;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      mainProgram = "herdr-app";
    };
  };
in
{ inherit herdr-core; } // lib.optionalAttrs (appRelease.targets ? ${target}) { inherit herdr-app; }
