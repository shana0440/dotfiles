# Shared coding-agent CLIs, managed by Nix rather than npm global installs.
{ pkgs, ... }:

{
  # Claude Code is distributed under a proprietary license.
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    claude-code
    codex
    opencode
    pi-coding-agent
  ];
}
