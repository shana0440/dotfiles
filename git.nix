# Shared Home Manager Git configuration for NixOS and macOS.
{ ... }:

{
  programs.git = {
    enable = true;
    settings.user = {
      name = "kwguo";
      email = "shana0440@gmail.com";
    };
  };
}
