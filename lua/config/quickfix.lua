-- ============================================================
-- QUICKFIX HUB (<leader>q)
-- ============================================================
-- One list for everything you step through with ]q / [q (built in): grep
-- results (:grep, or alt-q inside a picker), diagnostics, changed hunks, and
-- build or test failures.

-- :Cfilter /pattern/ keeps matching entries, :Cfilter! /pattern/ drops them.
vim.cmd.packadd("cfilter")

local map = vim.keymap.set

---@return boolean
local function quickfix_is_open()
	for _, win in ipairs(vim.fn.getwininfo()) do
		if win.quickfix == 1 and win.loclist == 0 and win.tabnr == vim.fn.tabpagenr() then
			return true
		end
	end
	return false
end

-- Open the list but leave the cursor in the code.
local function open_in_background()
	if not quickfix_is_open() then
		local win = vim.api.nvim_get_current_win()
		vim.cmd("botright copen")
		vim.api.nvim_set_current_win(win)
	end
end

map("n", "<leader>qq", function()
	if quickfix_is_open() then
		vim.cmd.cclose()
	else
		vim.cmd("botright copen")
	end
end, { desc = "[Q]uickfix toggle" })

-- ------------------------------------------------------------
-- Diagnostics and hunks into the list
-- ------------------------------------------------------------

---@param severity? vim.diagnostic.Severity
local function diagnostics_to_quickfix(severity)
	if #vim.diagnostic.get(nil, { severity = severity }) == 0 then
		vim.notify(severity and "No errors" or "No diagnostics")
		return
	end
	vim.diagnostic.setqflist({ severity = severity })
end

map("n", "<leader>qd", diagnostics_to_quickfix, { desc = "[Q]uickfix: all [D]iagnostics" })
map("n", "<leader>qe", function()
	diagnostics_to_quickfix(vim.diagnostic.severity.ERROR)
end, { desc = "[Q]uickfix: [E]rrors only" })

-- Servers normally report only open files. This asks the attached servers for
-- the whole workspace (not all support it); results arrive in the background.
map("n", "<leader>qw", function()
	vim.lsp.buf.workspace_diagnostics()
	vim.notify("Requested workspace diagnostics; <leader>qd lists them as they arrive")
end, { desc = "[Q]uickfix: request [W]orkspace diagnostics" })

-- Every changed hunk in the repository. In a jj repo this is the current change.
map("n", "<leader>qh", function()
	require("gitsigns").setqflist("all")
end, { desc = "[Q]uickfix: changed [H]unks" })

-- ------------------------------------------------------------
-- Build and test into the list (:Make, :Test)
-- ------------------------------------------------------------
-- A runner pairs a command with the errorformat that understands its output,
-- so switching to `just test` later only changes the command.
--   compiler   take the errorformat from this runtime compiler (:help :compiler)
--   efm        extra patterns, tried before the compiler's
--   transform  optional rewrite of the output lines before parsing

-- A failing Rust test reports its location and its message on two lines:
--   thread 'tests::adds' (123) panicked at src/lib.rs:11:9:
--   assertion `left == right` failed
-- Join them so one pattern yields the location together with the reason.
---@param lines string[]
---@return string[]
local function join_rust_panics(lines)
	local out = {}
	local i = 1
	while i <= #lines do
		if lines[i]:match("panicked at .+:%d+:%d+:$") and lines[i + 1] then
			out[#out + 1] = lines[i] .. " " .. vim.trim(lines[i + 1])
			i = i + 2
		else
			out[#out + 1] = lines[i]
			i = i + 1
		end
	end
	return out
end

-- `go test` prints test locations relative to each package (a_test.go:7), so
-- with ./... the file cannot be found. -json names the package for every
-- line; map it to a directory through go.mod and print cwd-relative paths.
---@param lines string[]
---@param cwd string
---@return string[]
local function go_test_json(lines, cwd)
	local gomod = vim.fs.find("go.mod", { path = cwd, upward = true, type = "file" })[1]
	local module, module_root
	if gomod then
		module_root = vim.fs.dirname(gomod)
		for line in io.lines(gomod) do
			module = line:match("^module%s+(%S+)")
			if module then
				break
			end
		end
	end

	---@param package string? import path
	---@return string? directory prefix, cwd-relative when possible
	local function package_dir(package)
		if not (module and package) then
			return nil
		end
		local dir
		if package == module then
			dir = module_root
		elseif vim.startswith(package, module .. "/") then
			dir = vim.fs.joinpath(module_root, package:sub(#module + 2))
		else
			return nil
		end
		local rel = vim.fs.relpath(cwd, dir) or dir
		return rel == "." and "" or rel .. "/"
	end

	local out = {}
	for _, line in ipairs(lines) do
		local ok, event = pcall(vim.json.decode, line)
		if not ok or type(event) ~= "table" then
			out[#out + 1] = line -- not JSON (a wrapper command's own output)
		elseif type(event.Output) == "string" then
			local text = event.Output:gsub("\n$", "")
			local file, rest = text:match("^%s+([^%s:/]+%.go)(:%d+:.*)$")
			local dir = file and package_dir(event.Package)
			out[#out + 1] = dir and (dir .. file .. rest) or text
		end
	end
	return out
end

local runners = {
	rust = {
		cmd = "cargo test",
		compiler = "cargo", -- rustc's compile errors
		efm = "%.%#panicked at %f:%l:%c: %m",
		transform = join_rust_panics,
	},
	python = { cmd = "pytest --tb=short -q", compiler = "pytest" },
	go = {
		cmd = "go test -json ./...",
		efm = "%f:%l:%c: %m,%f:%l: %m,%*\\s%f:%l: %m",
		transform = go_test_json,
	},
}

local compiler_efm = {}
-- The errorformat a runtime compiler sets, read in a scratch buffer so the
-- current buffer's own makeprg/errorformat stay untouched.
---@param name string
---@return string
local function errorformat_of(name)
	if not compiler_efm[name] then
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_call(buf, function()
			vim.cmd.compiler(name)
			compiler_efm[name] = vim.bo.errorformat ~= "" and vim.bo.errorformat or vim.go.errorformat
		end)
		vim.api.nvim_buf_delete(buf, { force = true })
	end
	return compiler_efm[name]
end

local running ---@type { job: vim.SystemObj?, cancelled: boolean }?

-- Stop the whole process group: the shell and everything it started (a test
-- binary, a compiler). Signalling only the shell left those running.
local function stop_running()
	if running and running.job then
		running.cancelled = true
		pcall(vim.uv.kill, -running.job.pid, "sigterm")
	end
end

-- The command runs detached (see below), so it would outlive Neovim.
vim.api.nvim_create_autocmd("VimLeavePre", {
	group = vim.api.nvim_create_augroup("user-quickfix-run", { clear = true }),
	desc = "Stop a running :Make or :Test",
	callback = stop_running,
})

-- Seeds the errorformat directory stack (%D), so relative paths in the output
-- resolve against the directory the command ran in, not wherever Neovim is by
-- the time it finishes (another tab, a :cd in between).
local enter_dir = "nvim-run: entering '%s'"
local enter_dir_efm = "%-D" .. enter_dir:format("%f")

-- Run `cmd` in the background and load its output into the quickfix list.
---@param cmd string shell command
---@param efm string
---@param transform? fun(lines: string[], cwd: string): string[]
local function run(cmd, efm, transform)
	if running then
		vim.notify("Still running; :MakeStop cancels it", vim.log.levels.WARN)
		return
	end
	local cwd = vim.fn.getcwd()
	vim.notify("Running: " .. cmd)
	local state = { cancelled = false }
	running = state
	-- `exec 2>&1` before the command: stderr of every part of a compound
	-- command (a && b) joins stdout, so errors keep their order with the rest.
	-- detach makes the shell a process group leader, so :MakeStop reaches all
	-- of its children.
	local argv = { "sh", "-c", "exec 2>&1\n" .. cmd }
	state.job = vim.system(argv, { text = true, cwd = cwd, detach = true }, function(result)
		vim.schedule(function()
			running = nil
			local lines = vim.split(result.stdout or "", "\n", { trimempty = true })
			if transform then
				lines = transform(lines, cwd)
			end
			table.insert(lines, 1, enter_dir:format(cwd))
			vim.fn.setqflist({}, " ", { title = cmd, lines = lines, efm = enter_dir_efm .. "," .. efm })

			-- Some patterns mark plain output (summaries, notes) as an error
			-- without a file. Keep those lines as context, but make ]q / [q
			-- stop only where there is somewhere to jump to.
			-- The directory marker line has done its job (entries now hold full
			-- paths), so it is dropped rather than shown.
			local items = vim.list_slice(vim.fn.getqflist(), 2)
			local locations = 0
			for _, item in ipairs(items) do
				if item.bufnr == 0 then
					item.valid = 0
				elseif item.valid == 1 then
					locations = locations + 1
				end
			end
			vim.fn.setqflist({}, "r", { title = cmd, items = items })
			if state.cancelled then
				vim.notify(cmd .. ": cancelled", vim.log.levels.WARN)
			elseif result.code == 0 then
				vim.notify(cmd .. ": passed")
			elseif result.signal ~= 0 then
				vim.notify(("%s: killed by signal %d"):format(cmd, result.signal), vim.log.levels.WARN)
			else
				local where = locations == 1 and "1 location" or (locations .. " locations")
				local message = ("%s: failed (exit %d), %s in quickfix"):format(cmd, result.code, where)
				vim.notify(message, vim.log.levels.ERROR)
				open_in_background()
			end
		end)
	end)
end

local last_test ---@type { cmd: string, efm: string, transform?: function }?

-- :Test [args]   run the tests for the current filetype; args are appended
--                (`:Test -k name`, `:Test -- --nocapture`). From a buffer with
--                no runner (the quickfix window, a README) it repeats the last
--                run. Set vim.g.test_cmd or vim.b.test_cmd (e.g. in .nvim.lua)
--                to replace the command, such as "just test".
vim.api.nvim_create_user_command("Test", function(opts)
	local runner = runners[vim.bo.filetype]
	if runner then
		local cmd = vim.b.test_cmd or vim.g.test_cmd or runner.cmd
		if opts.args ~= "" then
			cmd = cmd .. " " .. opts.args
		end
		local efm = runner.compiler and errorformat_of(runner.compiler) or ""
		if runner.efm then
			efm = efm == "" and runner.efm or (runner.efm .. "," .. efm)
		end
		last_test = { cmd = cmd, efm = efm, transform = runner.transform }
	elseif not last_test then
		vim.notify("No test runner for filetype '" .. vim.bo.filetype .. "'", vim.log.levels.WARN)
		return
	end
	run(last_test.cmd, last_test.efm, last_test.transform)
end, { nargs = "*", desc = "Run tests in the background, failures to quickfix" })

-- :Make [args]   :make without blocking: the buffer's 'makeprg' and
--                'errorformat', as set by :compiler (cargo, go, tsc, ruff ...).
vim.api.nvim_create_user_command("Make", function(opts)
	local makeprg = vim.bo.makeprg ~= "" and vim.bo.makeprg or vim.go.makeprg
	local cmd, substituted = makeprg:gsub("%$%*", (opts.args:gsub("%%", "%%%%")))
	if substituted == 0 and opts.args ~= "" then
		cmd = cmd .. " " .. opts.args
	end
	local efm = vim.bo.errorformat ~= "" and vim.bo.errorformat or vim.go.errorformat
	run(vim.fn.expandcmd(cmd), efm)
end, { nargs = "*", desc = "Run 'makeprg' in the background, errors to quickfix" })

vim.api.nvim_create_user_command("MakeStop", function()
	if running then
		stop_running()
	else
		vim.notify("Nothing is running")
	end
end, { desc = "Cancel the running :Make or :Test" })

map("n", "<leader>qt", "<cmd>Test<CR>", { desc = "[Q]uickfix: run [T]ests" })
map("n", "<leader>qm", "<cmd>Make<CR>", { desc = "[Q]uickfix: run [M]ake" })
