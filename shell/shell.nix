# Shared Home Manager shell configuration.
{ ... }:

{
  imports = [ ./fish.nix ];

  home.shellAliases.ll = "ls -lah";

  # Keep Bash configured as a fallback shell.
  programs.bash = {
    enable = true;
  };
}
