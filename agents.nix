# Shared coding-agent tools, managed by Nix rather than npm global installs.
{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    (import ./t3code/package.nix { inherit pkgs; })
    # Pi-Bolt has no Intel macOS release; keep upstream Pi on that platform.
    (if pkgs.stdenv.hostPlatform.system == "x86_64-darwin" then pi-coding-agent
     else import ./pi-bolt/package.nix { inherit pkgs inputs; })
  ];
}
