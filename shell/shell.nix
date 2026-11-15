{ ... }:

{
  imports = [ ./fish.nix ];

  home.shellAliases.ll = "ls -lah";

  programs.bash = {
    enable = true;
  };
}
