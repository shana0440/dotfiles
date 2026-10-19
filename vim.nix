# Shared Home Manager Neovim configuration for NixOS and macOS.
{ ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    initLua = ''
      vim.opt.number = true
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.undofile = true
      vim.opt.splitright = true
      vim.opt.splitbelow = true
    '';
  };
}
