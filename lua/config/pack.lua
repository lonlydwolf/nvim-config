-- ============================================================
-- PLUGINS (vim.pack)
-- ============================================================

-- Must be set before vim-tmux-navigator loads to suppress its default mappings
vim.g.tmux_navigator_no_mappings = 1

vim.pack.add({
	-- LSP: server configs only, no .setup() calls -- driven via native
	-- vim.lsp.enable() in config/lsp.lua
	{ src = "https://github.com/neovim/nvim-lspconfig" },
	{ src = "https://github.com/b0o/schemastore.nvim" },

	-- Completion. blink.cmp downloads a prebuilt fuzzy-matcher binary on first
	-- run; if that fails on your platform, `cargo build --release` inside the
	-- plugin dir builds it locally (see blink.cmp README).
	{ src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.*") },
	{ src = "https://github.com/rafamadriz/friendly-snippets" },

	-- Fuzzy finding (thin wrapper around the fzf binary + ripgrep)
	{ src = "https://github.com/ibhagwan/fzf-lua" },

	-- File explorer (edit the filesystem like a buffer)
	{ src = "https://github.com/stevearc/oil.nvim" },

	-- Treesitter -- community fork. The original neovim/nvim-treesitter was
	-- archived April 2026; this fork is an incompatible rewrite (distributed
	-- parser/query registry), which is fine since we're starting fresh.
	{ src = "https://github.com/neovim-treesitter/treesitter-parser-registry" },
	{ src = "https://github.com/neovim-treesitter/nvim-treesitter", version = "main" },

	-- Structural text objects, motions, and argument/element swaps -- mini.ai
	-- only covers selection, not motion or swap, so this fills that gap
	-- directly rather than being routed through mini.ai.
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },

	-- mini.nvim monorepo: Single clone providing 40+ lightweight modules
	-- We will use: mini.ai, mini.surround, mini.pairs, mini.indentscope
	--              mini.statusline, mini.notify, mini.icons, mini.bufremove
	-- (Modules remain dormant on disk and consume zero overhead until setup)
	{ src = "https://github.com/echasnovski/mini.nvim" },

	-- Git gutter signs, hunk stage/preview -- reads .git directly, so it works
	-- fine against a colocated jj/git backend
	{ src = "https://github.com/lewis6991/gitsigns.nvim" },

	-- Formatting + linting via CLI tools (not LSP servers)
	{ src = "https://github.com/stevearc/conform.nvim" },
	{ src = "https://github.com/mfussenegger/nvim-lint" },

	-- Theme
	{ src = "https://github.com/catppuccin/nvim", name = "catppuccin" },

	-- Split/pane navigation -- needs the matching TPM plugin in tmux.conf
	{ src = "https://github.com/christoomey/vim-tmux-navigator" },

	-- Keymap discovery popup -- intentionally temporary, remove once your
	-- own keymaps are muscle memory
	{ src = "https://github.com/folke/which-key.nvim" },

	-- Cursor line number mode indicator
	-- A small Neovim plugin that changes
	-- the color of your cursor's line number based on the current Vim mode.
	{ src = "https://github.com/mawkler/modicator.nvim" },

	-- nvim-hlslens helps you better glance at matched information,
	-- seamlessly jump between matched instances.
	{ src = "https://github.com/kevinhwang91/nvim-hlslens" },
})
