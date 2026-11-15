{ config, lib, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      git
      ripgrep
      stdenv.cc
      gnumake
      tree-sitter
      unzip
      curl
      nodejs
    ];
  };

  xdg.configFile."nvim/init.lua".enable = lib.mkForce false;

  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink
    "${config.dotfiles.directory}/neovim/config";
}
