# Install Neovim; editor settings and plugins live in native Lua files.
{ config, lib, pkgs, ... }:

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

  # Do not place a generated init.lua inside the live-linked directory.
  xdg.configFile."nvim/init.lua".enable = lib.mkForce false;

  # Link the whole directory so edits and newly added Lua files work immediately.
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles/neovim/config";
}
