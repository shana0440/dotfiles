# Shared coding-agent tools, managed by Nix rather than npm global installs.
{ pkgs, inputs, ... }:

let
  # Claude and Codex subscription limits as JSON, for the Quickshell dashboard.
  agentUsage = pkgs.writeShellApplication {
    name = "agent-usage";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./usage.py}
    '';
  };
in
{
  home.packages = with pkgs; [
    # Pi-Bolt has no Intel macOS release; keep upstream Pi on that platform.
    (if pkgs.stdenv.hostPlatform.system == "x86_64-darwin" then pi-coding-agent
     else import ./pi-bolt/package.nix { inherit pkgs inputs; })
    agentUsage
  ];
}
