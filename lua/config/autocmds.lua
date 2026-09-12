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

-- ============================================================
-- SESSION AUTO-SAVE / RESTORE
-- ============================================================
-- Exclude transient terminals from sessions so toggle states remain clean
vim.opt.sessionoptions:remove("terminal")

local session_dir = vim.fn.stdpath("state") .. "/sessions/"

-- Capture startup identity once: changing directories or argument lists later
-- will not alter this session's identity or eligibility.
local startup_cwd = vim.fn.getcwd()
local session_file = session_dir .. vim.fn.sha256(startup_cwd) .. ".vim"
local session_enabled = vim.fn.argc(-1) == 0

-- Attempt directory creation inside pcall; disable auto-session on failure
local ok_mkdir, mkdir_err = pcall(vim.fn.mkdir, session_dir, "p")
if not ok_mkdir then
	session_enabled = false
	vim.notify(
		"Failed to create session directory; auto-session disabled: " .. tostring(mkdir_err),
		vim.log.levels.WARN
	)
end

-- Safety guard: detect piped input (e.g. `cmd | nvim`)
local is_piped = false
vim.api.nvim_create_autocmd("StdinReadPre", {
	group = augroup,
	desc = "Detect piped stdin to prevent auto-session",
	callback = function()
		is_piped = true
	end,
})

vim.api.nvim_create_autocmd("VimEnter", {
	group = augroup,
	desc = "Auto-restore session for this project on startup",
	nested = true,
	callback = function()
		-- Safety guards: no file arguments, not piped, not headless
		if not session_enabled or is_piped or #vim.api.nvim_list_uis() == 0 then
			session_enabled = false
			return
		end

		if vim.fn.filereadable(session_file) == 1 then
			local ok, err = pcall(vim.cmd, "source " .. vim.fn.fnameescape(session_file))
			if not ok then
				-- Prevent broken partial state from overwriting session on exit
				session_enabled = false
				vim.notify("Failed to restore session: " .. tostring(err), vim.log.levels.WARN)
				return
			end
		end
	end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
	group = augroup,
	desc = "Auto-save session for this project on exit",
	callback = function()
		if not session_enabled or #vim.api.nvim_list_uis() == 0 then
			return
		end

		local ok_dir, dir_err = pcall(vim.fn.mkdir, session_dir, "p")
		if not ok_dir then
			vim.notify("Failed to create session directory: " .. tostring(dir_err), vim.log.levels.WARN)
			return
		end

		-- Preserve session identity if directory was changed during the session
		local current_cwd = vim.fn.getcwd()
		local switched = false
		if current_cwd ~= startup_cwd then
			local ok_cd, cd_err = pcall(vim.cmd, "noautocmd cd " .. vim.fn.fnameescape(startup_cwd))
			if not ok_cd then
				vim.notify(
					"Failed to switch back to startup directory; skipping session save: " .. tostring(cd_err),
					vim.log.levels.WARN
				)
				return
			end
			switched = true
		end

		local ok_save, save_err = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(session_file))
		if not ok_save then
			vim.notify("Failed to save session: " .. tostring(save_err), vim.log.levels.WARN)
		end

		if switched then
			local ok_rest, rest_err = pcall(vim.cmd, "noautocmd cd " .. vim.fn.fnameescape(current_cwd))
			if not ok_rest then
				vim.notify("Failed to restore working directory: " .. tostring(rest_err), vim.log.levels.WARN)
			end
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
