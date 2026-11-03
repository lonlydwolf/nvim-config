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
		-- COMMIT_EDITMSG reuses one path, so its saved cursor is from an old commit.
		-- (Filetype isn't detected yet at this point, so match the name.)
		if vim.fs.basename(ev.file) == "COMMIT_EDITMSG" then
			return
		end
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
		-- `nvim -S file.vim` already loaded a session: don't replace it, and don't
		-- overwrite this project's auto-session with it on exit.
		if vim.v.this_session ~= "" then
			session_enabled = false
			return
		end
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

		-- session_file is keyed to startup_cwd, so no `cd` is needed here; a global
		-- :cd would clear window/tab-local directories before they're recorded.
		local ok_save, save_err = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(session_file))
		if not ok_save then
			vim.notify("Failed to save session: " .. tostring(save_err), vim.log.levels.WARN)
		end
	end,
})

vim.filetype.add({
	-- docker_language_server only attaches to yaml.docker-compose. yamlls, prettier
	-- and yamllint still apply, since they all fall back to "yaml".
	filename = {
		["compose.yaml"] = "yaml.docker-compose",
		["compose.yml"] = "yaml.docker-compose",
		["docker-compose.yaml"] = "yaml.docker-compose",
		["docker-compose.yml"] = "yaml.docker-compose",
	},
	pattern = {
		[".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
		[".*/tasks/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*%.ya?ml"] = "yaml.ansible",
		["playbook.*%.ya?ml"] = "yaml.ansible",
	},
})
