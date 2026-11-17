-- ============================================================
-- QUICKFIX HUB (<leader>q)
-- ============================================================
-- One list for everything you step through with ]q / [q (built in): grep
-- results (:grep, or alt-q inside a picker), diagnostics and changed hunks.

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
