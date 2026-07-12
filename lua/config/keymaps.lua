-- ============================================================
-- KEYMAPS
-- ============================================================
local map = vim.keymap.set

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Repeatable window resizing
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

-- Buffer cycling + smart delete (keep window open)
map("n", "[b", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "]b", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bd", function()
	local current = vim.api.nvim_get_current_buf()
	local alt = vim.fn.bufnr("#")
	if alt ~= -1 and vim.api.nvim_buf_is_valid(alt) and vim.bo[alt].buflisted then
		vim.cmd("buffer #")
	else
		vim.cmd("bnext")
	end
	if vim.api.nvim_buf_is_valid(current) then
		vim.cmd("bdelete " .. current)
	end
end, { desc = "[B]uffer [D]elete  (keep window)" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Keep the cursor centered after jump-style movements (search, half-page
-- scroll, diagnostic jumps), without forcing permanent centering via
-- scrolloff during ordinary line-by-line movement.
map("n", "n", "nzz", { desc = "Next search match (centered)" })
map("n", "N", "Nzz", { desc = "Previous search match (centered)" })
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centered)" })
map("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
	vim.cmd("normal! zz")
end, { desc = "Previous diagnostic (centered)" })
map("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
	vim.cmd("normal! zz")
end, { desc = "Next diagnostic (centered)" })

-- Paste over a visual selection without the deleted selection overwriting
-- your yank register (routes the delete to the black-hole register instead)
map("x", "p", '"_dP', { desc = "Paste over selection without overwriting register" })

-- <leader>t "toggle" group
map("n", "<leader>ts", function()
	vim.wo.spell = not vim.wo.spell
end, { desc = "[T]oggle [S]pell Check" })
map("n", "<leader>tw", function()
	vim.wo.list = not vim.wo.list
end, { desc = "[T]oggle [W]hitespace glyphs" })
map("n", "<leader>tW", function()
	vim.wo.wrap = not vim.wo.wrap
end, { desc = "[T]oggle [W]rap" })

-- Native floating terminal toggle
local term_buf, term_win = nil, nil
local function toggle_terminal()
	if term_win and vim.api.nvim_win_is_valid(term_win) then
		vim.api.nvim_win_close(term_win, false)
		term_win = nil
		return
	end

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
	}

	if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
		term_win = vim.api.nvim_open_win(term_buf, true, win_opts)
	else
		term_buf = vim.api.nvim_create_buf(false, true)
		term_win = vim.api.nvim_open_win(term_buf, true, win_opts)
		vim.fn.termopen(vim.o.shell)
		vim.cmd.startinsert()
	end
end

map({ "n", "t" }, "<leader>tt", toggle_terminal, { desc = "[T]oggle [T]erminal (floating)" })
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Manual session save (auto save/restore-by-cwd lives in autocmds.lua).
-- Capital S, standalone -- lowercase <leader>ss is "search workspace
-- symbols" in the s-group (finder.lua), so this can't live there.
map("n", "<leader>S", function()
	vim.cmd("mksession! " .. vim.fn.stdpath("state") .. "/sessions/manual.vim")
	vim.notify("Session saved")
end, { desc = "Save session manually" })

-- <leader>c "Check" group
vim.keymap.set("n", "<leader>ch", "<cmd>checkhealth<CR>", { desc = "[C]heck [H]ealth (All)" })

vim.keymap.set("n", "<leader>cl", "<cmd>checkhealth vim.lsp<CR>", { desc = "[C]heck [L]SP Health" })

vim.keymap.set("n", "<leader>cf", "<cmd>ConformInfo<CR>", { desc = "[C]onform [F]ormatter Info" })

vim.keymap.set("n", "<leader>cL", function()
	local ft = vim.bo.filetype
	local linters = require("lint").linters_by_ft[ft]
	if linters then
		vim.print(linters)
	else
		vim.notify("No linters configured for filetype: " .. ft, vim.log.levels.INFO)
	end
end, { desc = "[C]heck [L]inters for buffer" })
