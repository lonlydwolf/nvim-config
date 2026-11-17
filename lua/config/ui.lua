-- ============================================================
-- UI
-- ============================================================

require("catppuccin").setup({
	flavour = "mocha",
	transparent_background = true,
	custom_highlights = function(colors)
		return {
			LspSignatureActiveParameter = { bold = true, bg = colors.surface1 },
			CursorLineNr = { fg = colors.lavender, bold = true },
			Visual = { bg = colors.surface2 },
			Search = { fg = colors.base, bg = colors.yellow },

			-- Modicator has no mini.statusline integration
			-- so we have to define the colors here for it to match mini.statusline
			NormalMode = { fg = colors.blue, bold = true },
			InsertMode = { fg = colors.green, bold = true },
			VisualMode = { fg = colors.mauve, bold = true },
			CommandMode = { fg = colors.peach, bold = true },
			ReplaceMode = { fg = colors.red, bold = true },
			SelectMode = { fg = colors.teal, bold = true },
			TerminalMode = { fg = colors.teal, bold = true },
			TerminalNormalMode = { fg = colors.blue, bold = true },

			-- Transparent Blink windows (here, so `:colorscheme catppuccin` keeps them)
			Pmenu = { bg = colors.none },
			BlinkCmpMenuBorder = { fg = colors.blue, bg = colors.none },
			BlinkCmpSignatureHelp = { bg = colors.none },
			BlinkCmpSignatureHelpBorder = { fg = colors.blue, bg = colors.none },
			BlinkCmpDoc = { bg = colors.none },
			BlinkCmpDocBorder = { fg = colors.blue, bg = colors.none },
		}
	end,
	integrations = {
		blink_cmp = true,
		gitsigns = true,
		mini = true,
		native_lsp = {
			enabled = true,
			underline = {
				errors = { "undercurl" },
				hints = { "undercurl" },
				warnings = { "undercurl" },
				information = { "undercurl" },
			},
		},
		treesitter = true,
	},
})
vim.cmd.colorscheme("catppuccin")

-- Default layout plus state that is otherwise invisible.
local statusline = require("mini.statusline")

-- Shown while format-on-save is toggled off (<leader>tf / <leader>tF).
local function section_autoformat()
	if vim.g.disable_autoformat then
		return "fmt off (global)"
	end
	return vim.b.disable_autoformat and "fmt off" or ""
end

statusline.setup({
	content = {
		active = function()
			local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
			local git = statusline.section_git({ trunc_width = 40 })
			local diff = statusline.section_diff({ trunc_width = 75 })
			local diagnostics = statusline.section_diagnostics({ trunc_width = 75 })
			local lsp = statusline.section_lsp({ trunc_width = 75 })
			local filename = statusline.section_filename({ trunc_width = 140 })
			local fileinfo = statusline.section_fileinfo({ trunc_width = 120 })
			local location = statusline.section_location({ trunc_width = 75 })
			local search = statusline.section_searchcount({ trunc_width = 75 })

			return statusline.combine_groups({
				{ hl = mode_hl, strings = { mode } },
				{ hl = "MiniStatuslineDevinfo", strings = { git, diff, diagnostics, lsp } },
				"%<", -- Mark general truncate point
				{ hl = "MiniStatuslineFilename", strings = { filename } },
				"%=", -- End left alignment
				{ hl = "DiagnosticWarn", strings = { section_autoformat() } },
				{ hl = "MiniStatuslineFileinfo", strings = { fileinfo } },
				{ hl = mode_hl, strings = { search, location } },
			})
		end,
	},
})

-- toast-only notifications, no cmdline/messages takeover
-- Blocked lsp progress list
local lsp_progress_blocklist = {
	pyright = true,
	basedpyright = true,
}

local notify = require("mini.notify")
notify.setup({
	content = {
		-- Clean Format: Strip timestamp and borders from LSP progress bars
		format = function(notif)
			if notif.data.source == "lsp_progress" then
				return notif.msg -- Return only the message text
			end
			return notify.default_format(notif) -- Keeps standard timestamps for regular toast notifications
		end,

		-- Ignore Unnecessary Info: Filter out background noise and spam before rendering
		sort = function(notif_arr)
			local filtered = vim.tbl_filter(function(n)
				-- Block empty notifications
				if n.msg == "" then
					return false
				end
				-- Block pyright/basedpyright progress and "Diagnosing" loops
				if n.data and n.data.source == "lsp_progress" then
					return not (lsp_progress_blocklist[n.data.client_name] or n.msg:find("Diagnosing", 1, true))
				end

				return true
			end, notif_arr)

			return notify.default_sort(filtered)
		end,
	},
})
-- Toasts never reach :messages, so errors stay up longer (default 5 s) and
-- <leader>n reopens everything shown this session in a normal, yankable buffer.
vim.notify = notify.make_notify({ ERROR = { duration = 10000 } })
vim.keymap.set("n", "<leader>n", notify.show_history, { desc = "[N]otification history" })

-- Initialize the icon provider
require("mini.icons").setup({
	-- 'glyph' is default. Can be changed to 'ascii' if your terminal lacks a Nerd Font.
	style = "glyph",
})

-- Masquerade as nvim-web-devicons to satisfy fzf-lua and other legacy dependencies
require("mini.icons").mock_nvim_web_devicons()

-- temporary: shows available keybindings on <leader>. remove once your
-- own keymaps are muscle memory (you said you'd revisit this).
local which_key = require("which-key")
which_key.setup()
which_key.add({
	{ "<leader>b", group = "[B]uffer" },
	{ "<leader>g", group = "[G]it" },
	{ "<leader>l", group = "[L]sp" },
	{ "<leader>s", group = "[S]earch" },
	{ "<leader>t", group = "[T]oggle" },
	{ "<leader>c", group = "[C]heck" },
})

-- Initialize Modicator.nvim
require("modicator").setup()

-- Initialize nvim-hlslens
require("hlslens").setup()
