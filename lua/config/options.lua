-- ============================================================
-- OPTIONS
-- ============================================================
------------------------------------
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
------------------------------------
local opt = vim.opt

-- UI
opt.number = true -- Line numbers
opt.relativenumber = true -- Reletive line numbers
opt.signcolumn = "yes" -- Always show a sign column
opt.cursorline = true -- Highlight current line
opt.scrolloff = 8 -- Keep 8 lines above/below cursor
opt.splitright = true -- Vertical splits go right
opt.splitbelow = true -- Horizontal splits go below
opt.updatetime = 300 -- Snappier LSP hover popups, diagnostics, and Git signs
opt.colorcolumn = "100" -- Visual guide for line length wrapping
opt.fillchars = { eob = " " } -- Hide'~' characters on blank lines past end-of-file
opt.pumheight = 10 -- popup menu height
opt.pumblend = 10 -- popup menu transparency
opt.winblend = 0 -- floating window transparency
opt.winborder = "rounded" -- Default border for floats (hover, diagnostics); matches completion and terminal
opt.showmode = false -- Mode is already shown by the statusline and the cursor line number
opt.shortmess:append("S") -- Search count is already shown by hlslens and the statusline

-- Editing
opt.expandtab = true -- Use spaces insted of tab
opt.shiftwidth = 2 -- Indent width
opt.tabstop = 2 -- Tab width
opt.smartindent = true -- Smart autoindent
opt.autoindent = true -- Copy indent from current line
opt.wrap = false -- Do not wrap lines by default
opt.clipboard:append("unnamedplus") -- Use system clipboard

-- On a machine with no clipboard tool (headless Linux over SSH, outside tmux)
-- the + register has no provider: Neovim's automatic OSC 52 fallback only
-- applies while 'clipboard' is unset. Wire it up explicitly for that case.
-- Copy goes to the local terminal through OSC 52. Paste returns what was last
-- copied from this Neovim instead of querying the terminal: with unnamedplus
-- every `p` would otherwise wait for an answer many terminals never send. Use
-- the terminal's own paste for text copied elsewhere.
local function has_clipboard_tool()
	local function exe(name)
		return vim.fn.executable(name) == 1
	end
	return exe("pbcopy")
		or (vim.env.WAYLAND_DISPLAY and exe("wl-copy"))
		or (vim.env.DISPLAY and (exe("xsel") or exe("xclip")))
		or exe("win32yank.exe")
		or (vim.env.TMUX and exe("tmux")) -- tmux buffer; `set-clipboard on` forwards it
end

if not vim.g.clipboard and not has_clipboard_tool() then
	local osc52 = require("vim.ui.clipboard.osc52")
	local last = { {}, "v" }
	local function copy(reg)
		local send = osc52.copy(reg)
		return function(lines, regtype)
			last = { lines, regtype }
			send(lines)
		end
	end
	local function paste()
		return last
	end
	vim.g.clipboard = {
		name = "OSC 52 (copy only)",
		copy = { ["+"] = copy("+"), ["*"] = copy("*") },
		paste = { ["+"] = paste, ["*"] = paste },
	}
end
opt.confirm = true -- Enable prompt to save changes

-- Search
opt.ignorecase = true -- Case insensitive search
opt.smartcase = true -- Case sensitive if uppercase in string
opt.incsearch = true -- Show matches as typing
opt.hlsearch = true -- Highlight search matches
-- :grep fills the quickfix list. The default adds -uu, which also searches
-- ignored and hidden files (.git, node_modules, build output).
opt.grepprg = "rg --vimgrep --smart-case"

-- Disk-backed, persistent undo history and crash recovery
opt.undofile = true
opt.swapfile = true
opt.backup = false
opt.writebackup = true

-- Fold
opt.foldmethod = "expr" -- Use expression for folding
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()" -- Use treesitter for folding
opt.foldtext = "" -- Use native syntax highlighting for folded lines
opt.foldlevel = 99 -- Open all folds by default
opt.foldlevelstart = 99 -- Ensure folds don't automatically close on file open

-- Snappier/Better Diffs and Command Line
-- Intelligently align lines inside diff hunks. Replace the default
-- linematch:40 rather than appending a second linematch entry.
opt.diffopt:remove("linematch:40")
opt.diffopt:append("linematch:60")
opt.wildmode = "longest:full,full" -- Bash/Zsh-like command line tab completion

-- Per Project Overrides
opt.exrc = true

-- Spell Lang
opt.spelllang = "en_us"

-- Visable whitespace
opt.list = true
opt.listchars = { tab = "» ", trail = "." }

-- Ensure mise-managed tools (LSPs, formatters, linters) are always found,
-- even when nvim is launched from a GUI that never sourced .zshrc.
-- A shell with `mise activate` has already put the install dirs on PATH, so
-- the (synchronous, ~27 ms) call is only made when they are missing.
if not (vim.env.PATH or ""):find("/mise/installs/", 1, true) then
	local ok, obj = pcall(function()
		-- Bounded: a hung mise must not hang startup (on timeout wait() kills it, code 124).
		return vim.system({ "mise", "bin-paths" }, { text = true }):wait(2000)
	end)

	if ok and obj.code == 0 then
		local stdout = vim.trim(obj.stdout)

		if stdout ~= "" then
			local dirs = vim.split(stdout, "\n", { trimempty = true })
			vim.env.PATH = table.concat(dirs, ":") .. ":" .. vim.env.PATH
		end
	end
end
