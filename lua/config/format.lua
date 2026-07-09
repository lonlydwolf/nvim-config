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

	c = function()
		-- Only run clang-tidy if compilation database exists
		if vim.fn.filereadable("compile_commands.json") == 1 then
			return { "clang-tidy" }
		end
		return {}
	end,

	cpp = function()
		if vim.fn.filereadable("compile_commands.json") == 1 then
			return { "clang_tidy" }
		end
		return {}
	end,

	rust = { "clippy" },
	go = { "staticcheck" },

	ansible = { "ansible_lint" },
}

-- Run lint on save + when leaving insert mode (balanced responsiveness)
vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
	group = vim.api.nvim_create_augroup("user-lint", { clear = true }),
	callback = function()
		require("lint").try_lint()
	end,
})
