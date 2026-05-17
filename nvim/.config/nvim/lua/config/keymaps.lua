local map = vim.keymap.set

map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
map("n", "<C-e>", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<C-p>", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Help tags" })

local function toggle_comment_current_line()
  require("Comment.api").toggle.linewise.current()
end

map("n", "<C-/>", toggle_comment_current_line, { desc = "Toggle comment" })
map("n", "<C-_>", toggle_comment_current_line, { desc = "Toggle comment" })
map("n", "<C-?>", toggle_comment_current_line, { desc = "Toggle comment" })
