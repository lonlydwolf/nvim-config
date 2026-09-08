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

-- Transparent Blink Menu and Signature
vim.api.nvim_set_hl(0, "Pmenu", { bg = "none" })
vim.api.nvim_set_hl(0, "BlinkCmpMenuBorder", { fg = "#89b4fa", bg = "none" })

require("mini.statusline").setup()

-- toast-only notifications, no cmdline/messages takeover
-- Blocked lsp progress list
local lsp_progress_blocklist = {
	pyright = true,
	basedpyright = true,
}

require("mini.notify").setup({
	content = {
		-- Clean Format: Strip timestamp and borders from LSP progress bars
		format = function(notif)
			if notif.data.source == "lsp_progress" then
				return notif.msg -- Return only the message text
			end
			return MiniNotify.default_format(notif) -- -- Keeps standard timestamps for regular toast notifications
		end,

		-- Ignore Unnecessary Info: Filter out background noise and spam before rendering
		sort = function(notif_arr)
			local filtered = vim.tbl_filter(function(n)
				-- Block empty notifications
				if n.msg == "" then
					return false
				end
				-- Block persistent background loops
				if n.msg:find("Diagnosing") then
					return false
				end
				-- Block pyright & basedpyright
				if n.data and n.data.source == "lsp_progress" then
					return not lsp_progress_blocklist[n.data.client_name]
				end

				return true
			end, notif_arr)

			return MiniNotify.default_sort(filtered)
		end,
	},
})
vim.notify = require("mini.notify").make_notify()

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
