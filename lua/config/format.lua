-- ============================================================
-- FORMATTERS & LINTERS
-- ============================================================

-- Formatting: conform.nvim (deterministic external formatters)
require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "ruff_format" },

		javascript = { "biome" },
		javascriptreact = { "biome" },
		typescript = { "biome" },
		typescriptreact = { "biome" },

		c = { "clang-format" },
		cpp = { "clang-format" },

		rust = { "rustfmt" },
		go = { "goimports" },

		sh = { "shfmt" },

		markdown = { "prettier" },
		yaml = { "prettier" },

		toml = { "taplo" },

		json = { "biome" },

		dockerfile = { "dockerfmt" },
		-- yaml.ansible needs no entry: conform falls back to "yaml" (prettier),
		-- and Prettier infers YAML from the filename. Lint fixes need :AnsibleFix.
	},

	-- Format on save (buffer-safe toggle aware)
	format_on_save = function(bufnr)
		if vim.b[bufnr].disable_autoformat then
			return
		end
		-- Prettier's startup can exceed 500 ms; keep other saves responsive.
		-- Inspect the selected formatter so project-specific choices work too.
		local timeout_ms = 500
		for _, formatter in ipairs(require("conform").list_formatters_to_run(bufnr)) do
			if formatter.name == "prettier" then
				timeout_ms = 2000
				break
			end
		end
		return { timeout_ms = timeout_ms, lsp_format = "fallback" }
	end,
})

-- Manual format trigger
vim.keymap.set("n", "<leader>f", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })

-- Explicit opt-in to ansible-lint --fix=all. Review the buffer diff before saving.
vim.api.nvim_create_user_command("AnsibleFix", function()
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.bo[bufnr].filetype ~= "yaml.ansible" then
		vim.notify("AnsibleFix requires an Ansible YAML buffer", vim.log.levels.WARN)
		return
	end
	if vim.bo[bufnr].buftype ~= "" or vim.api.nvim_buf_get_name(bufnr) == "" then
		vim.notify("AnsibleFix requires a named file buffer", vim.log.levels.WARN)
		return
	end

	require("conform").format({
		bufnr = bufnr,
		formatters = { "ansible-lint" },
		async = true,
		lsp_format = "never",
	})
end, { desc = "Apply Ansible lint fixes to buffer (review before saving)" })

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

local lint = require("lint")
lint.linters_by_ft = {
	dockerfile = { "hadolint" },
	yaml = { "yamllint" },
	["yaml.ansible"] = {}, -- Suppress yamllint fallback; ansiblels owns Ansible linting
	c = { "clangtidy" },
	cpp = { "clangtidy" },
}

-- clang-tidy only ships in Homebrew's keg-only llvm, which isn't on PATH.
local brew_tidy = "/opt/homebrew/opt/llvm/bin/clang-tidy"
if vim.fn.executable("clang-tidy") == 0 and vim.fn.executable(brew_tidy) == 1 then
	lint.linters.clangtidy.cmd = brew_tidy
end

-- yamllint and hadolint look for a project config from the cwd, so a file in
-- another project (or a nested dir like src/) gets the wrong rules. Resolve it
-- here instead, in the tool's own order but starting from the file, and always
-- pass the result so the tool never searches Neovim's cwd:
-- nearest project config above the file > user-wide config > tool defaults.
-- (try_lint's `cwd` option can't be used: nvim-lint implements it with a
-- global :cd, which clears :lcd/:tcd.)
local function with_config(name, flag, project_files, user_files, defaults)
	local linter = lint.linters[name]
	lint.linters[name] = function()
		local file = vim.api.nvim_buf_get_name(0)
		local config = file ~= ""
			and vim.fs.find(project_files, { path = vim.fs.dirname(file), upward = true, type = "file" })[1]
		config = config
			or vim.iter(user_files):map(vim.fs.normalize):find(function(f)
				return vim.fn.filereadable(f) == 1
			end)
		local config_args = config and { flag, config } or defaults
		return vim.tbl_extend(
			"force",
			linter,
			{ args = vim.list_extend(vim.list_extend({}, config_args), linter.args) }
		)
	end
end
local xdg = vim.env.XDG_CONFIG_HOME or "~/.config"
with_config(
	"yamllint",
	"-c",
	{ ".yamllint", ".yamllint.yaml", ".yamllint.yml" },
	{ vim.env.YAMLLINT_CONFIG_FILE or xdg .. "/yamllint/config" },
	{ "-d", "default" }
)
with_config("hadolint", "--config", { ".hadolint.yaml", ".hadolint.yml" }, {
	xdg .. "/hadolint.yaml",
	xdg .. "/hadolint.yml",
	"~/.hadolint/hadolint.yaml",
	"~/.hadolint/hadolint.yml",
	"~/.hadolint/config.yaml",
	"~/.hadolint/config.yml",
	"~/.hadolint.yaml",
	"~/.hadolint.yml",
}, { "--config", vim.fn.stdpath("config") .. "/lint/hadolint-defaults.yaml" })

-- Run all configured linters on save; only stdin-based linters on InsertLeave.
vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
	group = vim.api.nvim_create_augroup("user-lint", { clear = true }),
	callback = function(ev)
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
