{ ... }:

{
  programs.fish = {
    enable = true;
  };

  programs.fzf = {
    enableFishIntegration = true;
  };
  programs.direnv.enableFishIntegration = true;

}
