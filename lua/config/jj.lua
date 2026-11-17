-- ============================================================
-- JJ (Jujutsu)
-- ============================================================
-- jj is the primary VCS and its repos are colocated with git, so gitsigns
-- works unchanged: git's working-tree diff is exactly the current jj change.
-- What git cannot say is which change that is (it only sees a detached HEAD)
-- or where trunk is. This module answers both; ui.lua and editing.lua use it.
--
-- Every call passes --ignore-working-copy: reading state for a statusline must
-- never snapshot the working copy or add to the operation log.

local M = {}

local has_jj = vim.fn.executable("jj") == 1

---@param root string
---@param revset string
---@param template string
---@return string[] command
local function log_cmd(root, revset, template)
	return {
		"jj",
		"log",
		"--ignore-working-copy",
		"--no-graph",
		"--color=never",
		"-R",
		root,
		"-r",
		revset,
		"-T",
		template,
	}
end

-- Root of the jj repo containing the buffer's file, if any. Cached per buffer.
---@param bufnr integer
---@return string?
function M.root(bufnr)
	local cached = vim.b[bufnr].jj_root
	if cached ~= nil then
		return cached or nil
	end
	local name = vim.api.nvim_buf_get_name(bufnr)
	local root = has_jj and vim.bo[bufnr].buftype == "" and name ~= "" and vim.fs.root(name, ".jj") or false
	vim.b[bufnr].jj_root = root
	return root or nil
end

-- ------------------------------------------------------------
-- Statusline summary: "<change id> (<nearest bookmark>)"
-- ------------------------------------------------------------

-- Per repo root. `false` records a failed lookup, so it is not retried on
-- every statusline redraw (the autocmd below retries it).
local summaries = {} ---@type table<string, string|false>
local pending = {} ---@type table<string, boolean>

-- One line per revision: change id, "@" for the working copy, its bookmarks.
local summary_template = table.concat({
	"change_id.shortest(8)",
	'if(current_working_copy, "@", "")',
	'local_bookmarks.map(|b| b.name()).join(" ")',
}, ' ++ "\\t" ++ ') .. ' ++ "\\n"'

---@param root string
local function refresh(root)
	if pending[root] then
		return
	end
	pending[root] = true
	-- The working-copy change, plus the closest bookmarked ancestor(s).
	local cmd = log_cmd(root, "@ | heads(::@ & bookmarks())", summary_template)
	vim.system(cmd, { text = true }, function(result)
		vim.schedule(function()
			pending[root] = nil
			if result.code ~= 0 then
				summaries[root] = false
				return
			end
			local change, bookmarks = nil, {}
			for line in vim.gsplit(result.stdout or "", "\n", { trimempty = true }) do
				local id, at, names = unpack(vim.split(line, "\t"))
				if at == "@" then
					change = id
				end
				if names and names ~= "" then
					bookmarks[#bookmarks + 1] = names
				end
			end
			local text = change or false
			if change and #bookmarks > 0 then
				text = ("%s (%s)"):format(change, table.concat(bookmarks, " "))
			end
			if text ~= summaries[root] then
				summaries[root] = text
				vim.cmd.redrawstatus({ bang = true })
			end
		end)
	end)
end

-- Summary for the statusline, or nil outside a jj repo (or before the first
-- answer arrives; the statusline redraws when it does).
---@param bufnr integer
---@return string?
function M.summary(bufnr)
	local root = M.root(bufnr)
	if not root then
		return nil
	end
	if summaries[root] == nil then
		refresh(root)
	end
	return summaries[root] or nil
end

-- The change moves when you run jj in a terminal or another pane, so refresh
-- when coming back from one, and after writes (a new change may have started).
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "TermLeave", "BufWritePost" }, {
	group = vim.api.nvim_create_augroup("user-jj", { clear = true }),
	desc = "Refresh the jj change shown in the statusline",
	callback = function(ev)
		local root = M.root(ev.buf)
		if root then
			refresh(root)
		end
	end,
})

-- ------------------------------------------------------------
-- Trunk
-- ------------------------------------------------------------

-- Git commit id where the working copy's history forks from jj's trunk():
-- the newest commit that is an ancestor of both. Diffing against trunk()
-- itself would also show, reversed, whatever trunk gained since the fork.
---@param bufnr integer
---@return string?
function M.trunk_commit(bufnr)
	local root = M.root(bufnr)
	if not root then
		return nil
	end
	local result = vim.system(log_cmd(root, "heads(::@ & ::trunk())", 'commit_id ++ "\n"'), { text = true }):wait(2000)
	local commit = result.code == 0 and vim.trim(result.stdout or "") or ""
	commit = commit:match("^%x+") -- first line, should history fork in more than one place
	-- Without a remote, trunk() is the root commit (all zeros), which git cannot diff against.
	return commit and not commit:match("^0+$") and commit or nil
end

return M
