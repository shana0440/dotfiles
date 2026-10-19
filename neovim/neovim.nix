# Install Neovim; editor settings and plugins live in native Lua files.
{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Tools used by lazy.nvim, Telescope, and Treesitter.
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

  xdg.configFile = {
    "nvim/init.lua".source = ./config/init.lua;
    "nvim/lua" = {
      source = ./config/lua;
      recursive = true;
    };
    "nvim/queries" = {
      source = ./config/queries;
      recursive = true;
    };
    # lazy.nvim updates this file, so link to the writable checkout, not /nix/store.
    "nvim/lazy-lock.json".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/neovim/config/lazy-lock.json";
  };
}
