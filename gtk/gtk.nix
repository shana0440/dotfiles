{ pkgs, ... }:

let
  notwaitaCursor = pkgs.stdenvNoCC.mkDerivation {
    pname = "notwaita-cursor-black";
    version = "1.0.0-alpha1";
    src = pkgs.fetchzip {
      url = "https://github.com/ful1e5/notwaita-cursor/releases/download/v1.0.0-alpha1/Notwaita-Black.tar.xz";
      hash = "sha256-Wa7ELAZk+WEOM5B4gvPQP3UP/0kAB398+9yU2WFMYjE=";
      stripRoot = false;
    };
    installPhase = ''
      mkdir -p $out/share/icons
      cp -r Notwaita-Black $out/share/icons/
    '';
  };
in
{
  home.pointerCursor = {
    package = notwaitaCursor;
    name = "Notwaita-Black";
    size = 24;
    gtk.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
}
