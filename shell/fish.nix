{ ... }:

{
  programs.fish = {
    enable = true;
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
