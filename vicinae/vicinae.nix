{ config, lib, pkgs, ... }:

let
  settingsPath = "${config.xdg.configHome}/vicinae/settings.json";
  managedConfigName = "home-manager.json";
  initialSettings = pkgs.writeText "vicinae-initial-settings.json" (builtins.toJSON {
    imports = [ "./${managedConfigName}" ];
  });
in
{
  programs.vicinae.enable = true;

  xdg.configFile."vicinae/${managedConfigName}".text = builtins.toJSON {
    search_files_in_root = true;
  };

  home.activation.vicinaeInitializeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    settings=${lib.escapeShellArg settingsPath}
    if [[ ! -e "$settings" && ! -L "$settings" ]]; then
      run install -Dm600 ${initialSettings} "$settings"
    fi
  '';
}
