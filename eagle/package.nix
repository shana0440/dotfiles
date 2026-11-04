{ pkgs }:

let
  wine = pkgs.wineWow64Packages.stable;
  installer = pkgs.fetchurl {
    url = "https://r2-app.eagle.cool/releases/Eagle-4.0-x64-build23.exe";
    hash = "sha256-b5Kuy2xT9eOp3uSWBfGVWuEW4q3NXtLm3h0Z1zL5TTg=";
  };
  # Official favicon from eagle.cool (32x32), installed as an icon-theme icon so
  # launchers and Hyprland-aware panels can resolve Icon=eagle.
  icon = pkgs.fetchurl {
    url = "https://tw.eagle.cool/images/favicon.png";
    hash = "sha256-Unk10Tt0VPz34aTy7y6MLc7o0H3gfDL3cI41VWLxy54=";
  };
  iconTheme = pkgs.runCommand "eagle-icon" { } ''
    install -Dm644 ${icon} $out/share/icons/hicolor/32x32/apps/eagle.png
  '';
  desktop = pkgs.makeDesktopItem {
    name = "eagle";
    desktopName = "Eagle";
    icon = "eagle";
    comment = "Organize visual assets (Windows version via Wine)";
    exec = "eagle";
    categories = [ "Graphics" ];
    startupWMClass = "eagle.exe";
  };
  hideHelper = pkgs.writeShellApplication {
    name = "eagle-hide-helper";
    runtimeInputs = [
      pkgs.xdotool
      pkgs.xprop
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = builtins.readFile ./hide-helper.sh;
  };
  launcher = pkgs.writeShellApplication {
    name = "eagle";
    runtimeInputs = [
      wine
      pkgs.winetricks
      pkgs.coreutils
      pkgs.util-linux
      pkgs.jq
    ];
    text = ''
      export WINEPREFIX="''${EAGLE_WINEPREFIX:-''${XDG_DATA_HOME:-$HOME/.local/share}/eagle/wine}"
      export WINEDEBUG="''${WINEDEBUG:--all}"
      export WINE=${wine}/bin/wine
      export WINESERVER=${wine}/bin/wineserver
      mkdir -p "$WINEPREFIX"
      exec 9>"$WINEPREFIX/.eagle-setup.lock"
      flock 9
      if [[ ! -f "$WINEPREFIX/.eagle-dotnet48" ]]; then
        echo "Eagle: installing .NET 4.8 in a private Wine prefix (first launch may take several minutes)."
        # Suppress Mono/Gecko only in a new prefix. Eagle needs native .NET.
        if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
          WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe=d" wineboot -u
        fi
        unset WINEDLLOVERRIDES
        winetricks -q dotnet48
        winetricks -q win10
        touch "$WINEPREFIX/.eagle-dotnet48"
      else
        unset WINEDLLOVERRIDES
      fi
      export WINEDLLOVERRIDES="winemenubuilder.exe=d"
      if [[ ! -f "$WINEPREFIX/drive_c/Eagle/Eagle.exe" ]]; then
        echo "Eagle: installing 4.0 Build 23."
        wine ${installer} /S '/D=C:\Eagle'
        if [[ ! -f "$WINEPREFIX/drive_c/Eagle/Eagle.exe" ]]; then
          echo "Eagle installation did not produce C:\\Eagle\\Eagle.exe." >&2
          exit 1
        fi
      fi
      if [[ ! -f "$WINEPREFIX/.eagle-rendering-v2" ]]; then
        echo "Eagle: installing Windows core fonts and enabling font smoothing."
        winetricks -q corefonts fontsmooth=rgb
        touch "$WINEPREFIX/.eagle-rendering-v2"
      fi
      flock -u 9
      exec 9>&-
      scale_args=()
      # With compositor bitmap scaling disabled, let Electron render at the
      # focused monitor's native DPI instead of stretching a low-res image.
      if [[ "''${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]] \
        && command -v hyprctl >/dev/null \
        && hyprctl -j getoption xwayland:force_zero_scaling 2>/dev/null | jq -e '.bool == true' >/dev/null; then
        scale=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .scale' 2>/dev/null) || scale=""
        if [[ "$scale" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
          scale_args=("--force-device-scale-factor=$scale")
        fi
      fi
      wine "$WINEPREFIX/drive_c/Eagle/Eagle.exe" --disable-gpu "''${scale_args[@]}" "$@" &
      app_pid=$!
      ${hideHelper}/bin/eagle-hide-helper "$app_pid" &
      helper_pid=$!
      trap 'kill "$helper_pid" 2>/dev/null || true' EXIT
      status=0
      wait "$app_pid" || status=$?
      exit "$status"
    '';
  };
in
pkgs.symlinkJoin {
  name = "eagle-4.0-build23";
  paths = [
    launcher
    desktop
    iconTheme
  ];
  meta = {
    description = "Eagle visual asset manager, run with Wine and native .NET";
    homepage = "https://eagle.cool/";
    license = pkgs.lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "eagle";
  };
}
