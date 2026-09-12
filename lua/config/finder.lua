-- ============================================================
-- FINDER (fzf-lua)
-- ============================================================

local fzf = require("fzf-lua")
fzf.setup({})
fzf.register_ui_select()

local map = vim.keymap.set

-- Kickstart-style <leader>s "search" group
map("n", "<leader>sf", fzf.files, { desc = "[S]earch [F]iles" })
map("n", "<leader>sg", fzf.live_grep, { desc = "[S]earch [G]rep" })
map("n", "<leader>sw", fzf.grep_cword, { desc = "[S]earch [W]ord under cursor" })
map("n", "<leader>sh", fzf.helptags, { desc = "[S]earch [H]elp" })
map("n", "<leader>sk", fzf.keymaps, { desc = "[S]earch [K]eymaps" })
map("n", "<leader>sd", fzf.diagnostics_document, { desc = "[S]earch [D]iagnostics" })
map("n", "<leader>sl", fzf.lsp_references, { desc = "[S]earch [L]SP references" })
map("n", "<leader>sr", fzf.resume, { desc = "[S]earch [R]esume last" })
map("n", "<leader>s.", fzf.oldfiles, { desc = "[S]earch recent files" })
map("n", "<leader>ss", fzf.lsp_workspace_symbols, { desc = "[S]earch [S]ymbols workspace" })
map("n", "<leader>sS", fzf.builtin, { desc = "[S]earch [S]elect (meta)" })
map("n", "<leader>/", fzf.blines, { desc = "Search in current buffer" })
map("n", "<leader>sn", function()
	fzf.files({ cwd = vim.fn.stdpath("config") })
end, { desc = "[S]earch [N]eovim config" })

map("n", "<leader><leader>", fzf.buffers, { desc = "Find existing buffers" })
