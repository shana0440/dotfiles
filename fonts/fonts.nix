{ pkgs, ... }:

{
  home.packages = [ pkgs.adwaita-fonts pkgs.inter ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      sansSerif = [ "Adwaita Sans" "Noto Sans CJK TC" ];
      monospace = [ "Adwaita Mono" ];
    };
  };

  gtk = {
    enable = true;
    font = {
      name = "Adwaita Sans";
      size = 11;
    };
  };
}
