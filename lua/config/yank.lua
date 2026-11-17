-- ============================================================
-- CONTEXT YANK (<leader>y)
-- ============================================================
-- Copy what a colleague or an agent needs to act on a problem: diagnostics
-- with location, code and source line; file references; code with its path.
--
-- Everything is written to the + register, so Neovim's clipboard provider
-- picks the platform tool (pbcopy, wl-copy, xclip, tmux, OSC 52).

local M = {}

local severity_names = { "error", "warning", "info", "hint" }

-- Longest source excerpt attached to one diagnostic. Some servers report a
-- whole function or block as the range.
local max_context_lines = 3

-- Path relative to the repository root (.jj or .git) rather than Neovim's cwd,
-- so a reader working from the root can resolve it wherever nvim was started.
---@param name string absolute file name
---@return string
local function rel_path(name)
	if name == "" then
		return "[No Name]"
	end
	if name:match("^%a[%w+.-]*://") then
		return name -- oil://, term://, fugitive:// ...
	end
	local root = vim.fs.root(name, { { ".jj", ".git" } })
	local rel = root and vim.fs.relpath(root, name)
	return rel or vim.fn.fnamemodify(name, ":~:.")
end

-- Lines [first, last) of a buffer. Workspace diagnostics can point at buffers
-- that were never loaded, so fall back to the file on disk.
---@param bufnr integer
---@param first integer 0-based
---@param last integer 0-based, exclusive
---@return string[]
local function buf_lines(bufnr, first, last)
	if vim.api.nvim_buf_is_loaded(bufnr) then
		return vim.api.nvim_buf_get_lines(bufnr, first, last, false)
	end
	local ok, lines = pcall(vim.fn.readfile, vim.api.nvim_buf_get_name(bufnr), "", last)
	return ok and vim.list_slice(lines, first + 1, last) or {}
end

---@param d vim.Diagnostic
---@param with_source boolean include the offending source line(s)
---@return string
local function format_diagnostic(d, with_source)
	local tag = d.source and (d.code and ("%s: %s"):format(d.source, d.code) or d.source)
		or (d.code and tostring(d.code))
		or nil
	local lines = {
		("%s:%d:%d %s%s"):format(
			rel_path(vim.api.nvim_buf_get_name(d.bufnr)),
			d.lnum + 1,
			d.col + 1,
			severity_names[d.severity] or "unknown",
			tag and (" [" .. tag .. "]") or ""
		),
	}
	-- Blank lines separate entries, so drop the ones inside a message.
	for line in vim.gsplit(d.message, "\n", { plain = true, trimempty = true }) do
		if line:match("%S") then
			lines[#lines + 1] = "  " .. line
		end
	end

	local lsp = vim.tbl_get(d, "user_data", "lsp") or {}
	local href = vim.tbl_get(lsp, "codeDescription", "href")
	if href then
		lines[#lines + 1] = "  see: " .. href
	end
	for _, related in ipairs(lsp.relatedInformation or {}) do
		lines[#lines + 1] = ("  related: %s:%d %s"):format(
			rel_path(vim.uri_to_fname(related.location.uri)),
			related.location.range.start.line + 1,
			related.message
		)
	end

	if with_source then
		local last = math.max(d.end_lnum or d.lnum, d.lnum)
		local shown = math.min(last, d.lnum + max_context_lines - 1)
		for i, text in ipairs(buf_lines(d.bufnr, d.lnum, shown + 1)) do
			lines[#lines + 1] = ("  %d | %s"):format(d.lnum + i, text)
		end
		if shown < last then
			lines[#lines + 1] = ("  ... (through line %d)"):format(last + 1)
		end
	end
	return table.concat(lines, "\n")
end

-- Sorted by file and position, blank line between entries.
---@param diagnostics vim.Diagnostic[]
---@param with_source? boolean default true
---@return string
function M.format_diagnostics(diagnostics, with_source)
	local sorted = vim.list_slice(diagnostics)
	local names = {}
	local function name(d)
		names[d.bufnr] = names[d.bufnr] or vim.api.nvim_buf_get_name(d.bufnr)
		return names[d.bufnr]
	end
	table.sort(sorted, function(a, b)
		if a.bufnr ~= b.bufnr then
			return name(a) < name(b)
		end
		if a.lnum ~= b.lnum then
			return a.lnum < b.lnum
		end
		if a.col ~= b.col then
			return a.col < b.col
		end
		return a.severity < b.severity
	end)
	return table.concat(
		vim.tbl_map(function(d)
			return format_diagnostic(d, with_source ~= false)
		end, sorted),
		"\n\n"
	)
end

---@param text string
---@param what string shown in the confirmation, e.g. "3 diagnostics"
local function copy(text, what)
	vim.fn.setreg("+", text)
	vim.notify("Copied " .. what)
end

---@param diagnostics vim.Diagnostic[]
---@param where string used when there is nothing to copy
local function copy_diagnostics(diagnostics, where)
	if #diagnostics == 0 then
		vim.notify("No diagnostics " .. where)
		return
	end
	copy(M.format_diagnostics(diagnostics), ("%d diagnostic%s"):format(#diagnostics, #diagnostics == 1 and "" or "s"))
end

-- Line range of the active visual selection (1-based, ordered); leaves visual mode.
---@return integer first, integer last
local function visual_lines()
	local first, last = vim.fn.line("v"), vim.fn.line(".")
	vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
	return math.min(first, last), math.max(first, last)
end

---@param first integer 1-based
---@param last integer 1-based, inclusive
---@return vim.Diagnostic[]
local function diagnostics_in(first, last)
	return vim.tbl_filter(function(d)
		return d.lnum + 1 >= first and d.lnum + 1 <= last
	end, vim.diagnostic.get(0))
end

function M.line_diagnostics()
	local line = vim.fn.line(".")
	copy_diagnostics(diagnostics_in(line, line), "on this line")
end

function M.selection_diagnostics()
	local first, last = visual_lines()
	copy_diagnostics(diagnostics_in(first, last), "in the selection")
end

function M.buffer_diagnostics()
	copy_diagnostics(vim.diagnostic.get(0), "in this buffer")
end

function M.workspace_diagnostics()
	copy_diagnostics(vim.diagnostic.get(nil), "in the workspace")
end

-- fzf-lua action for the diagnostics pickers: copy the selected entries in
-- full. The picker truncates messages, so map each entry back to its diagnostic.
---@param selected string[]
---@param opts table
function M.picker_diagnostics(selected, opts)
	local fzf = require("fzf-lua")
	local diagnostics, seen = {}, {}
	for _, entry in ipairs(selected) do
		local file = fzf.path.entry_to_file(entry, opts)
		local bufnr = file.bufnr or (file.path and vim.fn.bufnr(file.path)) or -1
		if bufnr > 0 and file.line and file.line > 0 then
			-- Several tools can report at the same position (Ruff and basedpyright
			-- both flag an unused import), so narrow by column, then by the
			-- source and message text the entry shows. Each step is skipped if
			-- it would leave nothing.
			local text = fzf.utils.strip_ansi_coloring(entry)
			local matches = vim.diagnostic.get(bufnr, { lnum = file.line - 1 })
			for _, keep in ipairs({
				function(d)
					return d.col + 1 == file.col
				end,
				function(d)
					return d.source ~= nil and text:find("[" .. d.source .. "]", 1, true) ~= nil
				end,
				function(d)
					return text:find(d.message:match("^[^\n]*"), 1, true) ~= nil
				end,
			}) do
				local narrowed = vim.tbl_filter(keep, matches)
				matches = #narrowed > 0 and narrowed or matches
			end

			for _, d in ipairs(matches) do
				local key = table.concat({ bufnr, d.lnum, d.col, d.source or "", d.message }, "\0")
				if not seen[key] then
					seen[key] = true
					diagnostics[#diagnostics + 1] = d
				end
			end
		end
	end
	copy_diagnostics(diagnostics, "for the selected entries")
end

-- `path` for the buffer.
function M.path()
	local path = rel_path(vim.api.nvim_buf_get_name(0))
	copy(path, path)
end

-- `path:line`, or `path:first-last` for a selection: enough for a reader that
-- can open the file itself.
---@param first? integer
---@param last? integer
function M.location(first, last)
	first = first or vim.fn.line(".")
	last = last or first
	local ref = ("%s:%d"):format(rel_path(vim.api.nvim_buf_get_name(0)), first)
	if last ~= first then
		ref = ("%s-%d"):format(ref, last)
	end
	copy(ref, ref)
end

-- Fenced code block headed by `path:first-last`, followed by the diagnostics
-- inside that range. For readers that cannot open the file.
---@param first? integer
---@param last? integer
function M.code(first, last)
	first = first or vim.fn.line(".")
	last = last or first
	local code = vim.api.nvim_buf_get_lines(0, first - 1, last, false)

	-- A fence longer than any backtick run in the code keeps the block intact.
	local fence = "```"
	for _, line in ipairs(code) do
		for run in line:gmatch("`+") do
			if #run >= #fence then
				fence = ("`"):rep(#run + 1)
			end
		end
	end

	local ref = ("%s:%d"):format(rel_path(vim.api.nvim_buf_get_name(0)), first)
	if last ~= first then
		ref = ("%s-%d"):format(ref, last)
	end
	local out = { ref, fence .. (vim.bo.filetype:match("^[^.]+") or "") }
	vim.list_extend(out, code)
	out[#out + 1] = fence

	local diagnostics = diagnostics_in(first, last)
	if #diagnostics > 0 then
		-- The code is already above, so skip the per-diagnostic source lines.
		vim.list_extend(out, { "", "Diagnostics:", M.format_diagnostics(diagnostics, false) })
	end

	local what = ("%d line%s of code"):format(#code, #code == 1 and "" or "s")
	if #diagnostics > 0 then
		what = ("%s, %d diagnostic%s"):format(what, #diagnostics, #diagnostics == 1 and "" or "s")
	end
	copy(table.concat(out, "\n"), what)
end

-- ------------------------------------------------------------
-- Keymaps
-- ------------------------------------------------------------
local map = vim.keymap.set

map("n", "<leader>yd", M.line_diagnostics, { desc = "[Y]ank [D]iagnostics (line)" })
map("x", "<leader>yd", M.selection_diagnostics, { desc = "[Y]ank [D]iagnostics (selection)" })
map("n", "<leader>yD", M.buffer_diagnostics, { desc = "[Y]ank [D]iagnostics (buffer)" })
map("n", "<leader>yw", M.workspace_diagnostics, { desc = "[Y]ank [W]orkspace diagnostics" })

map("n", "<leader>yp", M.path, { desc = "[Y]ank [P]ath (repo-relative)" })
map("n", "<leader>yl", function()
	M.location()
end, { desc = "[Y]ank [L]ocation (path:line)" })
map("x", "<leader>yl", function()
	M.location(visual_lines())
end, { desc = "[Y]ank [L]ocation (path:first-last)" })

map("n", "<leader>yc", function()
	M.code()
end, { desc = "[Y]ank [C]ode with path and diagnostics (line)" })
map("x", "<leader>yc", function()
	M.code(visual_lines())
end, { desc = "[Y]ank [C]ode with path and diagnostics (selection)" })

return M
