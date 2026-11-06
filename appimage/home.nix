{ config, lib, pkgs, ... }:
let
  runner = import ./package.nix { inherit pkgs; };
  integrator = pkgs.writeShellApplication {
    name = "appimage-integrate";
    runtimeInputs = [ pkgs.python3 pkgs.desktop-file-utils ];
    text = ''
      exec python3 ${./integrate.py} --runner ${runner}/bin/appimage-run "$@"
    '';
  };
in {
  config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    home.packages = [ integrator ];

    home.activation.appimageApplicationsDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArg "${config.home.homeDirectory}/Applications"}
    '';

    systemd.user.services.appimage-integrate = {
      Unit.Description = "Integrate ~/Applications AppImages into the app launcher";
      Service = {
        Type = "oneshot";
        ExecStart = "${integrator}/bin/appimage-integrate";
      };
    };
    systemd.user.paths.appimage-integrate = {
      Unit.Description = "Watch ~/Applications for AppImages";
      Path = {
        PathChanged = "%h/Applications";
        Unit = "appimage-integrate.service";
      };
      Install.WantedBy = [ "default.target" ];
    };
    # Also notices writes to existing files and retries downloads after they settle.
    systemd.user.timers.appimage-integrate = {
      Unit.Description = "Refresh AppImage launcher entries";
      Timer = {
        OnStartupSec = "5s";
        OnUnitInactiveSec = "30s";
        Unit = "appimage-integrate.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
