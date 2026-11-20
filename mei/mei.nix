{ config, pkgs, inputs, ... }:

let
  mei = import ./package.nix { inherit pkgs; src = inputs.mei; };
  seedHome = pkgs.writeShellApplication {
    name = "mei-seed-home";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      home="''${MEI_HOME:-$HOME/.local/share/mei}"
      mkdir -p "$home"
      cp -r --no-preserve=mode --update=none ${mei}/lib/mei/template/. "$home"
    '';
  };
in
{
  home.packages = [ mei ];

  xdg.dataFile."mei/.agents/skills/desktop".source = config.lib.file.mkOutOfStoreSymlink
    "${config.dotfiles.directory}/mei/skills/desktop";

  systemd.user.services.mei = {
    Unit.Description = "mei personal assistant daemon";
    Service = {
      ExecStartPre = "${seedHome}/bin/mei-seed-home";
      ExecStart = "${mei}/bin/mei-daemon";
      Environment = "PATH=${config.home.homeDirectory}/.local/bin:${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
