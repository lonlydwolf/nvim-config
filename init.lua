vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Cache compiled Lua modules as bytecode; cuts require() time at startup.
vim.loader.enable()

-- Each module loads on its own: a failure in one (a broken plugin update, a
-- typo) is reported and the rest still load. Without this, one error skipped
-- every later module, including keymaps and session handling.
local modules = {
	"config.options", -- core vim.opt settings, folding, undofile, exrc
	"config.pack", -- vim.pack.add() -- all plugin sources
	"config.lsp", -- vim.lsp.enable(), server overrides, LspAttach keymaps
	"config.completion", -- blink.cmp
	"config.format", -- conform.nvim + nvim-lint
	"config.finder", -- fzf-lua + keymaps
	"config.editing", -- oil, treesitter, mini.ai/surround/pairs/indentscope, gitsigns
	"config.ui", -- catppuccin, mini.statusline, mini.notify, which-key
	"config.keymaps", -- general keymaps, terminal toggle, session save
	"config.yank", -- <leader>y: copy diagnostics, file references, code with context
	"config.quickfix", -- <leader>q: quickfix toggle, diagnostics/hunks to list, :Test and :Make
	"config.autocmds", -- yank flash, session save/restore
}

local failed = {}
for _, name in ipairs(modules) do
	local ok, err = xpcall(require, debug.traceback, name)
	if not ok then
		failed[#failed + 1] = ("%s failed to load:\n%s"):format(name, err)
	end
end

if #failed > 0 then
	-- Echo with history so the full traceback stays in :messages.
	vim.schedule(function()
		vim.api.nvim_echo({ { table.concat(failed, "\n\n") } }, true, { err = true })
	end)
end
