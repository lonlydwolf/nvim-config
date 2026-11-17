-- ============================================================
-- EDITING SETTINGS & KEYMAPS
-- ============================================================

-- File explorer: edit the filesystem like a normal buffer
require("oil").setup({
	default_file_explorer = true,
	keymaps = {
		-- Oil's defaults take <C-h> (split) and <C-l> (refresh), which breaks
		-- window/tmux navigation in oil buffers only. Free both and move the
		-- actions: <C-s> stays vertical split, <C-x> is horizontal, gR refreshes.
		["<C-h>"] = false,
		["<C-l>"] = false,
		["<C-x>"] = { "actions.select", opts = { horizontal = true } },
		["gR"] = "actions.refresh",
	},
})
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory (Oil)" })

-- Treesitter (upstream, main branch). ensure_installed is no longer a setup()
-- option in the rewrite -- you call install() yourself. This diffs against
-- what's already installed so it doesn't reinstall on every launch.
require("nvim-treesitter").setup({
	install_dir = vim.fn.stdpath("data") .. "/site",
})

local ensure_installed = {
	"lua",
	"python",
	"javascript",
	"typescript",
	"tsx",
	"ecma",
	"jsx",
	"go",
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
	-- Filetypes that already have an LSP/linter/formatter here, or show up in
	-- everyday VCS and build work, but had no parser.
	"dockerfile",
	"gitcommit",
	"diff",
	"gomod",
	"make",
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

-- Installing parsers does not enable highlighting on the main branch.
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("user-treesitter-highlight", { clear = true }),
	desc = "Enable Treesitter highlighting when a parser is available",
	callback = function(ev)
		if vim.bo[ev.buf].buftype ~= "" then
			return
		end
		-- Skip quietly when no parser is available; let real errors (broken queries) show.
		local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
		if lang and vim.treesitter.language.add(lang) then
			vim.treesitter.start(ev.buf, lang)
		end
	end,
})

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

-- Sticky context: pins the line that opens the enclosing function/class (up
-- to three levels) at the top of the window while its body is scrolled.
require("treesitter-context").setup({
	max_lines = 3,
	multiline_threshold = 1, -- a wrapped signature takes one line, not all three
})
vim.keymap.set("n", "<leader>tc", "<cmd>TSContext toggle<CR>", { desc = "[T]oggle sticky [C]ontext" })
-- Jump up to the line the context shows.
vim.keymap.set("n", "[c", function()
	if vim.wo.diff then
		-- Keep the built-in "previous change" in diff mode, count included.
		vim.cmd.normal({ vim.v.count1 .. "[c", bang = true })
	else
		require("treesitter-context").go_to_context(vim.v.count1)
	end
end, { desc = "Jump to enclosing context" })

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
-- The runtime ftplugins for Python, Rust and Go define buffer-local, regex-based
-- [[ ]] [m ]m maps that would shadow the treesitter motions below in exactly
-- those languages. These globals turn those ftplugin maps off.
vim.g.no_python_maps = 1
vim.g.no_rust_maps = 1
vim.g.no_go_maps = 1

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
-- mini.ai's default an/in/al/il deliberately override Neovim 0.12's built-in
-- incremental selection (v_an grows by syntax node, v_in shrinks). Move the
-- next/last variants to capitals, as mini.ai's own docs suggest, to get both.
require("mini.ai").setup({
	mappings = {
		around_next = "aN",
		inside_next = "iN",
		around_last = "aL",
		inside_last = "iL",
	},
})

-- Add/replace/delete surrounding pairs: sa / sr / sd
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

-- Buffer removal preserving window layouts
require("mini.bufremove").setup()

-- Git gutter signs / hunk actions. Reads .git directly, so this works against
-- a jj repo with a colocated git backend: the gutter is the current jj change.
-- After `jj new` it is empty, so everything that then appears is what changed
-- since (an agent's edits, for instance): walk it with ]h / [h, preview with
-- <leader>gp, reject a hunk with <leader>gr, list all with <leader>qh.
local jj = require("config.jj")

-- <leader>gt state: the base each repository's gutter compares against while it
-- shows "everything since trunk", keyed by repository root. Per repository,
-- because a commit from one repository does not exist in another.
local trunk_bases = {} ---@type table<string, string>

---@param bufnr integer
---@return string? root the buffer's repository root, as gitsigns resolved it
local function repo_root(bufnr)
	local status = vim.b[bufnr].gitsigns_status_dict
	return status and status.root
end

-- Point one buffer's gutter at `base` (nil: back to the current change). Its
-- "base: trunk" statusline marker follows the result, not the request.
-- A failed switch to trunk also drops the repository's trunk state, so the
-- next <leader>gt retries it and later attaches do not re-apply it.
---@param bufnr integer
---@param base string?
---@param on_success? fun()
local function set_buffer_base(bufnr, base, on_success)
	vim.api.nvim_buf_call(bufnr, function()
		require("gitsigns").change_base(base, false, function(err)
			vim.schedule(function()
				if not vim.api.nvim_buf_is_valid(bufnr) then
					return
				end
				if err then
					local root = repo_root(bufnr)
					if base and root and trunk_bases[root] == base then
						trunk_bases[root] = nil
					end
					local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":~:.")
					vim.notify(("Could not change the diff base of %s: %s"):format(name, err), vim.log.levels.WARN)
					return
				end
				vim.b[bufnr].gitsigns_base_is_trunk = base ~= nil
				vim.cmd.redrawstatus({ bang = true })
				if on_success then
					on_success()
				end
			end)
		end)
	end)
end

-- Apply `base` to every loaded buffer of the repository. `on_success` runs
-- once the `current` buffer has switched, so the confirmation follows the
-- result, not the request.
---@param root string
---@param base string?
---@param current integer
---@param on_success fun()
local function set_repo_base(root, base, current, on_success)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and repo_root(buf) == root then
			set_buffer_base(buf, base, buf == current and on_success or nil)
		end
	end
end

require("gitsigns").setup({
	-- A file jj has not snapshotted yet is untracked to git. Attach anyway, so a
	-- newly created file shows up in the gutter and in <leader>qh.
	attach_to_untracked = true,
	on_attach = function(bufnr)
		local gs = require("gitsigns")
		local function gmap(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { buf = bufnr, desc = desc })
		end

		-- Every attach (a newly opened file, or a reload after :edit or an
		-- external change) starts from the default base, so reset the marker,
		-- and re-apply the trunk base if this repository has one. That has to
		-- wait for gitsigns' own first update of the buffer, which would
		-- otherwise overwrite it.
		vim.b[bufnr].gitsigns_base_is_trunk = false
		local root = repo_root(bufnr)
		if root and trunk_bases[root] then
			vim.api.nvim_create_autocmd("User", {
				pattern = "GitSignsUpdate",
				desc = "Re-apply the trunk diff base after gitsigns attaches",
				callback = function(ev)
					if not (ev.data and ev.data.buffer == bufnr) then
						return
					end
					if vim.api.nvim_buf_is_valid(bufnr) and trunk_bases[root] then
						set_buffer_base(bufnr, trunk_bases[root])
					end
					return true -- once
				end,
			})
		end

		-- Navigation lives on brackets (same family as native [d/]d), actions
		-- live under <leader>g
		gmap("n", "]h", function()
			gs.nav_hunk("next")
		end, "Next hunk")
		gmap("n", "[h", function()
			gs.nav_hunk("prev")
		end, "Previous hunk")
		gmap({ "o", "x" }, "ih", gs.select_hunk, "Inside hunk")

		gmap("n", "<leader>gr", gs.reset_hunk, "[G]it [R]eset hunk")
		-- Visual actions operate on selected lines, not the entire cursor hunk.
		gmap("x", "<leader>gr", function()
			gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, "[G]it [R]eset selected lines")
		gmap("n", "<leader>gp", gs.preview_hunk, "[G]it [P]review hunk")
		gmap("n", "<leader>gb", gs.toggle_current_line_blame, "[G] Toggle line [B]lame")
		gmap("n", "<leader>gd", gs.diffthis, "[G]it [D]iff this file")

		-- Staging means nothing under jj (there is no index to commit from), so
		-- the stage keys exist only in plain git repos.
		if not jj.root(bufnr) then
			gmap("n", "<leader>gs", gs.stage_hunk, "[G]it [S]tage hunk")
			gmap("x", "<leader>gs", function()
				gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, "[G]it [S]tage selected lines")
		end

		-- Widen the gutter from "the current change" to "everything since
		-- trunk", for reviewing a whole stack or branch. Applies to every open
		-- buffer of this repository; the statusline shows "base: trunk" there.
		gmap("n", "<leader>gt", function()
			local repo = repo_root(bufnr)
			if not repo then
				return
			end
			if trunk_bases[repo] then
				trunk_bases[repo] = nil
				set_repo_base(repo, nil, bufnr, function()
					vim.notify("Gutter shows the current change")
				end)
				return
			end
			-- The fork point with trunk: jj's trunk(), or the remote's default
			-- branch in a plain git repo.
			local base
			if jj.root(bufnr) then
				base = jj.trunk_commit(bufnr)
			else
				local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
				local result = vim.system({ "git", "merge-base", "HEAD", "origin/HEAD" }, { cwd = dir, text = true })
					:wait(2000)
				base = result.code == 0 and vim.trim(result.stdout) or nil
			end
			if not base then
				vim.notify("Could not find trunk for this repository", vim.log.levels.WARN)
				return
			end
			trunk_bases[repo] = base
			set_repo_base(repo, base, bufnr, function()
				vim.notify("Gutter shows everything since trunk in " .. vim.fn.fnamemodify(repo, ":~"))
			end)
		end, "[G]it: toggle diff base (current change / [T]runk)")
	end,
})

-- jj's diff editor. `jj split`, `jj squash -i`, `jj commit -i`, `jj restore -i`
-- ... open Neovim with a file tree and a side-by-side diff; pick what belongs
-- in the change, then accept. Wired up through `ui.diff-editor` in
-- ~/.config/jj/config.toml. Inside it: `a` toggles a file or line, `A` a hunk,
-- <Tab> switches sides, <leader><CR> accepts, q aborts, g? lists the keys.
require("hunk").setup()
