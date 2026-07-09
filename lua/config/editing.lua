-- ============================================================
-- EDITING SETTINGS & KEYMAPS
-- ============================================================

-- File explorer: edit the filesystem like a normal buffer
require("oil").setup({
	default_file_explorer = true,
})
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory (Oil)" })

-- Treesitter (community fork). ensure_installed is no longer a setup()
-- option in the rewrite -- you call install() yourself. This diffs against
-- what's already installed so it doesn't reinstall on every launch.
require("nvim-treesitter").setup({
	install_dir = vim.fn.stdpath("data") .. "/site",
})

local ensure_installed = {
	"lua",
	"python",
	"c",
	"cpp",
	"rust",
	"bash",
	"markdown",
	"markdown_inline",
	"yaml",
	"json",
	"toml",
	"vim",
	"vimdoc",
	"query",
}
local already_installed = require("nvim-treesitter.config").get_installed()
local to_install = vim.iter(ensure_installed)
	:filter(function(parser)
		return not vim.tbl_contains(already_installed, parser)
	end)
	:totable()
if #to_install > 0 then
	require("nvim-treesitter").install(to_install)
end

-- Structural text objects, motions, and swaps. mini.ai only covers
-- selection, not motion or swap, so this is a separate, focused plugin
-- rather than routed through mini.ai.
require("nvim-treesitter-textobjects").setup({
	select = {
		lookahead = true,
		selection_modes = {
			["@parameter.outer"] = "v",
			["@function.outer"] = "V",
			["@class.outer"] = "V",
		},
	},
	move = { set_jumps = true },
})

local ts_select = require("nvim-treesitter-textobjects.select")
local ts_move = require("nvim-treesitter-textobjects.move")
local ts_swap = require("nvim-treesitter-textobjects.swap")

-- Selection (operator-pending + visual)
vim.keymap.set({ "x", "o" }, "af", function()
	ts_select.select_textobject("@function.outer", "textobjects")
end, { desc = "Around function" })
vim.keymap.set({ "x", "o" }, "if", function()
	ts_select.select_textobject("@function.inner", "textobjects")
end, { desc = "Inside function" })
vim.keymap.set({ "x", "o" }, "ac", function()
	ts_select.select_textobject("@class.outer", "textobjects")
end, { desc = "Around class" })
vim.keymap.set({ "x", "o" }, "ic", function()
	ts_select.select_textobject("@class.inner", "textobjects")
end, { desc = "Inside class" })
vim.keymap.set({ "x", "o" }, "aa", function()
	ts_select.select_textobject("@parameter.outer", "textobjects")
end, { desc = "Around parameter" })
vim.keymap.set({ "x", "o" }, "ia", function()
	ts_select.select_textobject("@parameter.inner", "textobjects")
end, { desc = "Inside parameter" })

-- Motion
vim.keymap.set({ "n", "x", "o" }, "]m", function()
	ts_move.goto_next_start("@function.outer", "textobjects")
end, { desc = "Next function start" })
vim.keymap.set({ "n", "x", "o" }, "]M", function()
	ts_move.goto_next_end("@function.outer", "textobjects")
end, { desc = "Next function end" })
vim.keymap.set({ "n", "x", "o" }, "[m", function()
	ts_move.goto_previous_start("@function.outer", "textobjects")
end, { desc = "Previous function start" })
vim.keymap.set({ "n", "x", "o" }, "[M", function()
	ts_move.goto_previous_end("@function.outer", "textobjects")
end, { desc = "Previous function end" })
vim.keymap.set({ "n", "x", "o" }, "]]", function()
	ts_move.goto_next_start("@class.outer", "textobjects")
end, { desc = "Next class" })
vim.keymap.set({ "n", "x", "o" }, "][", function()
	ts_move.goto_next_end("@class.outer", "textobjects")
end, { desc = "Next class end" })
vim.keymap.set({ "n", "x", "o" }, "[[", function()
	ts_move.goto_previous_start("@class.outer", "textobjects")
end, { desc = "Previous class" })
vim.keymap.set({ "n", "x", "o" }, "[]", function()
	ts_move.goto_previous_end("@class.outer", "textobjects")
end, { desc = "Previous class end" })

-- Swap
vim.keymap.set("n", "<leader>a", function()
	ts_swap.swap_next("@parameter.inner")
end, { desc = "Swap next parameter" })
vim.keymap.set("n", "<leader>A", function()
	ts_swap.swap_previous("@parameter.inner")
end, { desc = "Swap previous parameter" })

-- Text objects (brackets/quotes/custom -- not function/class/parameter,
-- which nvim-treesitter-textobjects handles above)
require("mini.ai").setup()

-- Add/change/delete surrounding pairs: ys/cs/ds-style operators
require("mini.surround").setup()

-- Auto-close brackets/quotes
require("mini.pairs").setup()

-- Current-scope indent highlighting, animation disabled
local indentscope = require("mini.indentscope")
indentscope.setup({
	draw = {
		animation = indentscope.gen_animation.none(),
	},
})

-- Git gutter signs / hunk actions. Reads .git directly, so this works fine
-- against a jj repo with a colocated git backend.
require("gitsigns").setup({
	on_attach = function(bufnr)
		local gs = require("gitsigns")
		local function gmap(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
		end

		-- Navigation lives on brackets (same family as native [d/]d), actions
		-- live under <leader>g
		gmap("n", "]h", gs.next_hunk, "Next hunk")
		gmap("n", "[h", gs.prev_hunk, "Previous hunk")
		gmap({ "n", "v" }, "<leader>gs", gs.stage_hunk, "[G]it [S]tage hunk")
		gmap({ "n", "v" }, "<leader>gr", gs.reset_hunk, "[G]it [R]eset hunk")
		gmap("n", "<leader>gp", gs.preview_hunk, "[G]it [P]review hunk")
		gmap("n", "<leader>gb", gs.toggle_current_line_blame, "[G] Toggle line [B]lame")
		gmap("n", "<leader>gd", gs.diffthis, "[G]it [D]iff this file")
	end,
})
