# Shared Home Manager shell configuration.
{ ... }:

{
  imports = [ ./fish.nix ];

  # Keep Bash configured as a fallback shell.
  programs.bash = {
    enable = true;
  };
}
