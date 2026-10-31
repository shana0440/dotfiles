{ pkgs, ... }:

{
  home.packages = [ pkgs.adwaita-fonts ];

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
