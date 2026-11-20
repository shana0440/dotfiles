{ ... }:

{
  programs.fish = {
    enable = true;
    shellAliases.cd = "z";
  };

  programs.fzf = {
    enableFishIntegration = true;
  };
  programs.direnv.enableFishIntegration = true;

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
  };

}
