-- ============================================================
-- COMPLETION
-- ============================================================

require("blink.cmp").setup({
	keymap = {
		preset = "default",
		-- kickstart habit: <cr> always inserts a plain newline, never silently
		-- accepts a completion. <c-y> is the explicit, deliberate accept key.
		["<cr>"] = { "fallback" },
		["<c-y>"] = { "select_and_accept", "fallback" },
	},
	appearance = {
		nerd_font_variant = "mono",
	},
	completion = {
		-- manual-only documentation popup (<c-space> toggles it, per the
		-- default preset -- covers both "reopen the menu" and "show docs").
		documentation = {
			auto_show = false,
			window = { border = "rounded" },
		},
		-- faint inline preview of the top candidate ahead of the cursor
		ghost_text = {
			enabled = true,
			show_without_selection = true,
		},
		-- arrowing through the list will not provisionally insert
		-- the highlighted item into the buffer.
		list = { selection = { preselect = false, auto_insert = false } },
		-- Automatically open the completion menu when typing characters defined by LSP
		trigger = { show_on_trigger_character = true },
		-- Organize the visual metadata inside the completion list
		menu = {
			border = "rounded",
			draw = {
				treesitter = { "lsp" },
				columns = {
					{ "kind_icon" },
					{ "label", "label_description", gap = 1 },
					{ "source_name" },
				},
			},
		},
	},
	sources = {
		default = { "lsp", "path", "snippets", "buffer" },
		providers = {
			buffer = { score_offset = -3 },
		},
	},

	-- Handle the parameter help overlay when typing inside function parentheses
	signature = {
		enabled = true,
		window = {
			border = "rounded",
		},
	},
	-- native vim.snippet engine (no luasnip). friendly-snippets is picked up
	-- automatically once installed as a plugin -- no extra wiring needed.
	snippets = { preset = "default" },
	fuzzy = { implementation = "prefer_rust_with_warning" },
})
