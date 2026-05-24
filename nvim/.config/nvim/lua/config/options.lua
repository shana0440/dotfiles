local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smartindent = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.splitright = true
opt.splitbelow = true
opt.ignorecase = true
opt.smartcase = true
opt.clipboard = "unnamedplus"
opt.autoread = true
opt.list = true
opt.listchars = {
  space = "·",
  tab = ">-",
}

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  command = "checktime",
})
