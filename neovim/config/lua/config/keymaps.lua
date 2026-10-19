local map = vim.keymap.set

vim.api.nvim_create_user_command("Reveal", "NvimTreeFindFile", {})

map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
map("n", "<C-e>", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<C-p>", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
map("n", "bp", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "bn", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Help tags" })
map("n", "<leader>f", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format file" })
map("n", "<F1>", function()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local diagnostics = vim.diagnostic.get(0, { lnum = line })

  if #diagnostics > 0 then
    vim.diagnostic.open_float()
  else
    vim.diagnostic.goto_next()
  end
end, { desc = "Show line diagnostics or go to next diagnostic" })
local function show_references()
  local actions = require("telescope.actions")

  require("telescope.builtin").lsp_references({
    previewer = true,
    layout_strategy = "vertical",
    layout_config = {
      preview_cutoff = 1,
      preview_height = 0.6,
      prompt_position = "top",
      mirror = true,
    },
    attach_mappings = function(_, map_telescope)
      map_telescope({ "i", "n" }, "<C-s>", actions.select_horizontal)
      map_telescope({ "i", "n" }, "<C-v>", actions.select_vertical)
      return true
    end,
  })
end

map("n", "<F2>", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local uri = vim.uri_from_bufnr(bufnr)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local params = vim.lsp.util.make_position_params(0, "utf-16")

  vim.lsp.buf_request(bufnr, "textDocument/definition", params, function(err, result)
    if err or not result or vim.tbl_isempty(result) then
      vim.schedule(vim.lsp.buf.definition)
      return
    end

    local locations = vim.tbl_islist(result) and result or { result }
    for _, location in ipairs(locations) do
      local target_uri = location.targetUri or location.uri
      local range = location.targetSelectionRange or location.targetRange or location.range

      if target_uri == uri and range and range.start.line <= cursor_line and cursor_line <= range["end"].line then
        vim.schedule(show_references)
        return
      end
    end

    vim.schedule(function()
      vim.lsp.util.jump_to_location(locations[1], "utf-16", true)
    end)
  end)
end, { desc = "Go to definition or list references" })
map("n", "<S-F2>", show_references, { desc = "List references with preview" })
map("n", "<S-F6>", vim.lsp.buf.rename, { desc = "Rename symbol" })
map("n", "<F3>", function()
  require("gitsigns").next_hunk()
end, { desc = "Next git change" })
map({ "n", "t" }, "<C-`>", "<cmd>ToggleTerm direction=float<CR>", { desc = "Toggle floating terminal" })
map("n", "<leader>hs", function()
  require("gitsigns").stage_hunk()
end, { desc = "Stage git hunk" })
map("v", "<leader>hs", function()
  require("gitsigns").stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
end, { desc = "Stage selected git lines" })

local function toggle_comment_current_line()
  require("Comment.api").toggle.linewise.current()
end

map("n", "<C-/>", toggle_comment_current_line, { desc = "Toggle comment" })
map("n", "<C-_>", toggle_comment_current_line, { desc = "Toggle comment" })
map("n", "<C-?>", toggle_comment_current_line, { desc = "Toggle comment" })
