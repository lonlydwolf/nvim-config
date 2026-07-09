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

-- Editing
opt.expandtab = true -- Use spaces insted of tab
opt.shiftwidth = 2 -- Indent width
opt.tabstop = 2 -- Tab width
opt.smartindent = true -- Smart autoindent
opt.autoindent = true -- Copy indent from current line
opt.wrap = false -- Do not wrap lines by default
opt.clipboard:append("unnamedplus") -- Use system clipboard
opt.confirm = true -- Enable prompt to save changes

-- Search
opt.ignorecase = true -- Case insensitive search
opt.smartcase = true -- Case sensitive if uppercase in string
opt.incsearch = true -- Show matches as typing
opt.hlsearch = true -- Highlight search matches

-- Disk-backed, presistant undo history
opt.undofile = true -- Do create undo file
-- opt.undodir is not needed since nvim default is $XDG_STATE_HOME/nvim/undo//
opt.swapfile = false -- Do not creat swap file
opt.backup = false -- Do not create backup file
opt.writebackup = false -- Do not write to backup file

-- Fold
opt.foldmethod = "expr" -- Use expression for folding
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()" -- Use treesitter for folding
opt.foldtext = "" -- Use native syntax highlighting for folded lines
opt.foldlevel = 99 -- Open all folds by default
opt.foldlevelstart = 99 -- Ensure folds don't automatically close on file open

-- Snappier/Better Diffs and Command Line
opt.diffopt:append("linematch:60") -- Intelligently align lines inside diff hunks
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
vim.env.PATH = vim.fn.expand("~/.local/share/mise/shims") .. ":" .. vim.env.PATH
