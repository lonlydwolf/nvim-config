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
map("x", "<leader>sw", fzf.grep_visual, { desc = "[S]earch [W]ord / Selection" })
map("n", "<leader>sh", fzf.helptags, { desc = "[S]earch [H]elp" })
map("n", "<leader>sk", fzf.keymaps, { desc = "[S]earch [K]eymaps" })
map("n", "<leader>sd", fzf.diagnostics_document, { desc = "[S]earch [D]iagnostics (Buffer)" })
map("n", "<leader>sD", fzf.diagnostics_workspace, { desc = "[S]earch [D]iagnostics (Workspace)" })
map("n", "<leader>sl", fzf.lsp_references, { desc = "[S]earch [L]SP references" })
map("n", "<leader>so", fzf.lsp_document_symbols, { desc = "[S]earch document [O]utline (Symbols)" })
map("n", "<leader>ss", fzf.lsp_workspace_symbols, { desc = "[S]earch [S]ymbols workspace" })
map("n", "<leader>sr", fzf.resume, { desc = "[S]earch [R]esume last" })
map("n", "<leader>s.", fzf.oldfiles, { desc = "[S]earch recent files" })
map("n", "<leader>sq", fzf.quickfix, { desc = "[S]earch [Q]uickfix list" })
map("n", "<leader>sj", fzf.jumps, { desc = "[S]earch [J]umplist" })
map("n", '<leader>s"', fzf.registers, { desc = '[S]earch Registers (")' })
map("n", "<leader>sS", fzf.builtin, { desc = "[S]earch [S]elect (meta)" })
map("n", "<leader>/", fzf.blines, { desc = "Search in current buffer" })
map("n", "<leader>sn", function()
	fzf.files({ cwd = vim.fn.stdpath("config") })
end, { desc = "[S]earch [N]eovim config" })

map("n", "<leader><leader>", fzf.buffers, { desc = "Find existing buffers" })

-- Git search group (<leader>g)
map("n", "<leader>gS", fzf.git_status, { desc = "[G]it [S]tatus (all files)" })
map("n", "<leader>gc", fzf.git_commits, { desc = "[G]it [C]ommits (project)" })
map("n", "<leader>gC", fzf.git_bcommits, { desc = "[G]it [C]ommits (buffer)" })

-- Spelling suggestions
map("n", "z=", fzf.spell_suggest, { desc = "Fuzzy spell suggestions" })
