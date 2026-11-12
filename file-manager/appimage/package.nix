{ pkgs }:
let
  # Apply scaling after extraction, so only Electron images receive Chromium flags.
  scaledExec = pkgs.runCommand "appimage-exec-scaled" { } ''
    mkdir -p "$out/bin"
    cp ${pkgs.appimageTools.appimage-exec}/bin/appimage-exec.sh "$out/bin/"
    chmod u+w "$out/bin/appimage-exec.sh"
    substituteInPlace "$out/bin/appimage-exec.sh" \
      --replace-fail 'exec "$APPDIR/AppRun" "$@"' ${pkgs.lib.escapeShellArg ''
        export QT_SCALE_FACTOR="''${QT_SCALE_FACTOR:-1}"
        export GDK_DPI_SCALE="''${GDK_DPI_SCALE:-1}"
        if [ -f "$APPDIR/resources/app.asar" ] || [ -f "$APPDIR/chrome-sandbox" ]; then
          case " $* " in
            *" --force-device-scale-factor="*) ;;
            *) set -- --force-device-scale-factor=1 "$@" ;;
          esac
        fi
        exec "$APPDIR/AppRun" "$@"
      ''}
  '';
in
pkgs.appimage-run.override {
  appimageTools = pkgs.appimageTools // { appimage-exec = scaledExec; };
}
