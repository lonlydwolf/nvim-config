-- ============================================================
-- AUTOCMDS
-- ============================================================

local augroup = vim.api.nvim_create_augroup("user-autocmds", { clear = true })

-- Briefly highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
	group = augroup,
	desc = "Briefly highlight yanked text",
	callback = function()
		vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
	end,
})

-- Return to the last cursor position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
	group = augroup,
	desc = "Jump to last known cursor position",
	callback = function(ev)
		local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
		local line_count = vim.api.nvim_buf_line_count(ev.buf)
		if mark[1] > 0 and mark[1] <= line_count then
			vim.api.nvim_win_set_cursor(0, mark)
		end
	end,
})

-- Per-language indent width. .editorconfig (native support, on by default)
-- wins over this when a project provides one; this is just the fallback
-- for projects that don't.
vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = { "python", "c", "cpp", "rust" },
	desc = "Use 4-space indentation for these languages",
	callback = function()
		vim.bo.shiftwidth = 4
		vim.bo.tabstop = 4
	end,
})

-- Session auto-save/restore, keyed by a hash of cwd so different projects
-- don't collide. Only triggers when Nvim was opened with no file arguments
-- (`nvim` alone, not `nvim somefile.lua`).
local session_dir = vim.fn.stdpath("state") .. "/sessions/"
vim.fn.mkdir(session_dir, "p")

local function session_file()
	return session_dir .. vim.fn.sha256(vim.fn.getcwd()) .. ".vim"
end

vim.api.nvim_create_autocmd("VimLeavePre", {
	group = augroup,
	desc = "Auto-save session for this project on exit",
	callback = function()
		if vim.fn.argc() == 0 then
			vim.cmd("mksession! " .. session_file())
		end
	end,
})

vim.api.nvim_create_autocmd("VimEnter", {
	group = augroup,
	desc = "Auto-restore session for this project on startup",
	nested = true,
	callback = function()
		if vim.fn.argc() == 0 and vim.fn.filereadable(session_file()) == 1 then
			vim.cmd("source " .. session_file())
		end
	end,
})

vim.filetype.add({
	pattern = {
		[".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
		[".*/tasks/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*%.ya?ml"] = "yaml.ansible",
		["playbook.*%.ya?ml"] = "yaml.ansible",
	},
})
