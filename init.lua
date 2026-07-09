vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options") -- core vim.opt settings, folding, undofile, exrc
require("config.pack") -- vim.pack.add() -- all plugin sources
require("config.lsp") -- vim.lsp.enable(), server overrides, LspAttach keymaps
require("config.completion") -- blink.cmp
require("config.format") -- conform.nvim + nvim-lint
require("config.finder") -- fzf-lua + keymaps
require("config.editing") -- oil, treesitter, mini.ai/surround/pairs/indentscope, gitsigns
require("config.ui") -- catppuccin, mini.statusline, mini.notify, which-key
require("config.keymaps") -- general keymaps, terminal toggle, session save
require("config.autocmds") -- yank flash, session save/restore
