{ pkgs }:

let
  wine = pkgs.wineWow64Packages.stable;
  # Nexon serves the current installer from a fixed, unversioned URL, so it is
  # downloaded on first launch instead of being pinned with fetchurl.
  installerUrl = "https://download.nxfs.nexon.com/download-launcher?file=NexonLauncherSetup.exe";
  favicon = pkgs.fetchurl {
    url = "https://web.nxfs.nexon.com/arena-home/static/images/nexon.ico";
    hash = "sha256-04NjNHwkc4v/jr+7zWid0V6xmHPIxqlw3pmQ9Tx4+1M=";
  };
  iconTheme = pkgs.runCommand "nexon-icon" { nativeBuildInputs = [ pkgs.icoutils ]; } ''
    mkdir ico
    icotool -x -o ico ${favicon}
    for f in ico/*.png; do
      size=$(basename "$f" .png | sed -E 's/.*_([0-9]+)x[0-9]+x[0-9]+$/\1/')
      install -Dm644 "$f" "$out/share/icons/hicolor/''${size}x''${size}/apps/nexon-launcher.png"
    done
  '';
  desktop = pkgs.makeDesktopItem {
    name = "nexon-launcher";
    desktopName = "Nexon Launcher";
    icon = "nexon-launcher";
    comment = "Nexon game launcher (Windows version via Wine)";
    exec = "nexon-launcher";
    categories = [ "Game" ];
    startupWMClass = "nexon_client.exe";
  };
  launcher = pkgs.writeShellApplication {
    name = "nexon-launcher";
    runtimeInputs = [
      wine
      pkgs.winetricks
      pkgs.curl
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      data="''${XDG_DATA_HOME:-$HOME/.local/share}/nexon"
      export WINEPREFIX="''${NEXON_WINEPREFIX:-$data/wine}"
      export WINEDEBUG="''${WINEDEBUG:--all}"
      export WINE=${wine}/bin/wine
      export WINESERVER=${wine}/bin/wineserver
      mkdir -p "$WINEPREFIX"
      exec 9>"$WINEPREFIX/.nexon-setup.lock"
      flock 9
      if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
        echo "Nexon: creating Wine prefix."
        # The launcher is Chromium based and needs neither Mono nor Gecko.
        WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe=d" wineboot -u
      fi
      export WINEDLLOVERRIDES="winemenubuilder.exe=d"
      if [[ ! -f "$WINEPREFIX/.nexon-rendering" ]]; then
        echo "Nexon: installing core fonts and selecting Windows 10."
        winetricks -q win10 corefonts
        touch "$WINEPREFIX/.nexon-rendering"
      fi
      launcher_exe="$WINEPREFIX/drive_c/Program Files (x86)/Nexon/Nexon Launcher/nexon_launcher.exe"
      if [[ ! -f "$launcher_exe" ]]; then
        echo "Nexon: downloading and installing Nexon Launcher."
        curl -fL -o "$data/NexonLauncherSetup.exe" "${installerUrl}"
        wine "$data/NexonLauncherSetup.exe" /S
        if [[ ! -f "$launcher_exe" ]]; then
          echo "Nexon installation did not produce nexon_launcher.exe." >&2
          exit 1
        fi
      fi
      flock -u 9
      exec 9>&-
      # Its embedded Chromium cannot use the GPU or sandbox under Wine.
      exec wine "$launcher_exe" --no-sandbox --disable-gpu "$@"
    '';
  };
in
pkgs.symlinkJoin {
  name = "nexon-launcher";
  paths = [
    launcher
    desktop
    iconTheme
  ];
  meta = {
    description = "Nexon Launcher, run with Wine";
    homepage = "https://www.nexon.com/";
    license = pkgs.lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "nexon-launcher";
  };
}
