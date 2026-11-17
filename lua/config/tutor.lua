-- ============================================================
-- TUTOR (:Tutor config, :TutorSandbox)
-- ============================================================
-- `:Tutor config` opens tutor/config.tutor, the guided tour of this setup.
-- Its lessons are practised in a throwaway project, so nothing real is ever
-- edited: :TutorSandbox copies tutor/sandbox/ into the cache directory, makes
-- it a repository with a clean baseline, and opens it in its own tab.

local template = vim.fs.joinpath(vim.fn.stdpath("config"), "tutor", "sandbox")
local sandbox = vim.fs.joinpath(vim.fn.stdpath("cache"), "tutor-sandbox")

---@param cmd string[]
---@return boolean ok
local function run(cmd)
	local ok, result = pcall(function()
		return vim.system(cmd, { cwd = sandbox, text = true }):wait(15000)
	end)
	return ok and result.code == 0
end

-- A fresh copy of the template with one baseline commit, so the gutter starts
-- empty and every edit made during the lessons shows up as a change.
---@return boolean ok
local function create()
	vim.fn.delete(sandbox, "rf")
	vim.fn.mkdir(sandbox, "p")
	for name, type in vim.fs.dir(template) do
		if type == "file" then
			vim.uv.fs_copyfile(vim.fs.joinpath(template, name), vim.fs.joinpath(sandbox, name))
		end
	end

	if vim.fn.executable("jj") == 1 then
		-- Never sign in the sandbox: signing can prompt for a key passphrase.
		return run({ "jj", "git", "init", "--colocate" })
			and run({ "jj", "config", "set", "--repo", "signing.behavior", "drop" })
			and run({ "jj", "commit", "-m", "tutor: baseline" })
	end
	local identity = { "-c", "user.name=tutor", "-c", "user.email=tutor@localhost", "-c", "commit.gpgsign=false" }
	return run({ "git", "init", "-q" })
		and run({ "git", "add", "-A" })
		and run(vim.list_extend(vim.list_extend({ "git" }, identity), { "commit", "-q", "-m", "tutor: baseline" }))
end

-- :TutorSandbox   open the practice project in its own tab (creating it on
--                 first use). gt / gT switch between it and the tutor.
-- :TutorSandbox!  throw the project away and start from a clean copy.
vim.api.nvim_create_user_command("TutorSandbox", function(opts)
	if opts.bang or not vim.uv.fs_stat(sandbox) then
		if not create() then
			vim.notify("Could not set up the tutor sandbox in " .. sandbox, vim.log.levels.ERROR)
			return
		end
		vim.cmd("silent! checktime") -- reload sandbox buffers that were already open
		vim.notify("Tutor sandbox ready: " .. vim.fn.fnamemodify(sandbox, ":~"))
	end

	-- Reuse the sandbox tab if there is one.
	local real = vim.uv.fs_realpath(sandbox) or sandbox
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local nr = vim.api.nvim_tabpage_get_number(tab)
		if vim.fn.haslocaldir(-1, nr) == 1 and (vim.uv.fs_realpath(vim.fn.getcwd(-1, nr)) or "") == real then
			vim.api.nvim_set_current_tabpage(tab)
			return
		end
	end
	vim.cmd.tabnew()
	vim.cmd.tcd(vim.fn.fnameescape(sandbox))
	vim.cmd.edit("orders.py")
end, { bang = true, desc = "Open (or with ! reset) the practice project for :Tutor config" })
