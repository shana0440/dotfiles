{ pkgs, inputs, ... }:

let
  hasPiBoltRelease = pkgs.stdenv.hostPlatform.system != "x86_64-darwin";
  agentUsage = pkgs.writeShellApplication {
    name = "agent-usage";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./usage.py}
    '';
  };
in
{
  home.packages = with pkgs; [
    (if hasPiBoltRelease then import ./pi-bolt/package.nix { inherit pkgs inputs; }
     else pi-coding-agent)
    agentUsage
  ];
}
