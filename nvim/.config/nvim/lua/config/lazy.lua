local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Theme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight")
    end,
  },

  -- 2) File explorer
  {
    "nvim-tree/nvim-tree.lua",
    commit = vim.fn.has("nvim-0.10") == 1 and nil or "e16cd38962bc40c22a51ee004aa4f43726d74a16",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        renderer = {
          icons = {
            show = {
              file = false,
              folder = false,
              folder_arrow = false,
              git = false,
            },
          },
        },
      })
    end,
  },

  -- 3) Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({})
    end,
  },

  -- 4) Better syntax parsing/highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    version = vim.fn.has("nvim-0.10") == 1 and "*" or "v0.9.3",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "lua", "vim", "vimdoc", "bash", "json", "markdown", "markdown_inline" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- 6) Autocompletion (nvim-cmp)
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
        }),
      })
    end,
  },

  -- 9) Comment toggling
  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup({})
    end,
  },

  -- 7) Statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "auto",
          globalstatus = true,
          icons_enabled = false,
        },
      })
    end,
  },

  -- 8) Git signs + inline blame
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        current_line_blame = true,
      })
    end,
  },

  -- 5) LSP + server manager
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            package_installed = "+",
            package_pending = ">",
            package_uninstalled = "x",
          },
        },
      })
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls" },
        automatic_enable = true,
      })

      if vim.lsp and vim.lsp.config and vim.lsp.enable then
        vim.lsp.config("lua_ls", {
          capabilities = capabilities,
        })
        vim.lsp.enable("lua_ls")
      else
        local lspconfig = require("lspconfig")
        lspconfig.lua_ls.setup({
          capabilities = capabilities,
        })
      end
    end,
  },
}, {
  checker = { enabled = true },
  ui = {
    icons = {
      cmd = "C",
      config = "Cfg",
      event = "E",
      ft = "Ft",
      init = "I",
      keys = "K",
      plugin = "P",
      runtime = "R",
      source = "S",
      start = "*",
      task = "T",
      lazy = "L",
    },
  },
})
