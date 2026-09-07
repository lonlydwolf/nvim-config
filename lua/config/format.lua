-- ============================================================
-- FORMATTERS & LINTERS
-- ============================================================

-- Formatting: conform.nvim (deterministic external formatters)
require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "ruff_format" },

		javascript = { "biome" },
		typescript = { "biome" },

		c = { "clang_format" },
		cpp = { "clang_format" },

		rust = { "rustfmt" },
		go = { "goimports" },

		sh = { "shfmt" },

		markdown = { "prettier" },
		yaml = { "prettier" },

		toml = { "taplo" },

		json = { "biome" },

		dockerfile = { "dockerfmt" },

		ansible = { "ansible-lint" },
	},

	-- Format on save (buffer-safe toggle aware)
	format_on_save = function(bufnr)
		if vim.b[bufnr].disable_autoformat then
			return
		end
		return { timeout_ms = 500, lsp_format = "fallback" }
	end,
})

-- Manual format trigger
vim.keymap.set("n", "<leader>f", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })

-- Toggle format-on-save (buffer-local)
vim.keymap.set("n", "<leader>tf", function()
	vim.b.disable_autoformat = not vim.b.disable_autoformat
	vim.notify("Format on save (buffer): " .. (vim.b.disable_autoformat and "off" or "on"))
end, { desc = "[T]oggle [F]ormat on save (buffer)" })

-- ============================================================
-- LINTING (strictly non-LSP complementary tools)
-- ============================================================

-- Principle:
-- Only run linters that provide meaningful analysis beyond LSP or formatter tools.

require("lint").linters_by_ft = {
	dockerfile = { "hadolint" },
	yaml = { "yamllint" },
	sh = { "shellcheck" },

	c = { "clangtidy" },
	cpp = { "clangtidy" },

	rust = { "clippy" },
	go = { "staticcheck" },

	ansible = { "ansible_lint" },
}

-- Run all configured linters on save; only stdin-based linters on InsertLeave.
vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
	group = vim.api.nvim_create_augroup("user-lint", { clear = true }),
	callback = function(ev)
		local lint = require("lint")
		if ev.event == "InsertLeave" then
			-- Disk-based tools would inspect stale files and may trigger expensive builds.
			lint.try_lint(nil, { filter = "stdin" })
			return
		end

		local ft = vim.bo[ev.buf].filetype
		if ft == "c" or ft == "cpp" then
			local filename = vim.api.nvim_buf_get_name(ev.buf)
			if filename == "" then
				return
			end

			-- Search from the source file, not Neovim's working directory.
			local database = vim.fs.find({ "compile_commands.json", "build/compile_commands.json" }, {
				path = vim.fs.dirname(filename),
				upward = true,
				type = "file",
			})[1]
			if not database then
				return
			end

			lint.try_lint("clangtidy", {
				wrap_linter = function(linter)
					-- -p also supports databases kept in a separate build directory.
					linter.args = vim.list_extend(vim.deepcopy(linter.args), { "-p", vim.fs.dirname(database) })
					return linter
				end,
			})
			return
		end

		lint.try_lint()
	end,
})
