-- ============================================================
-- FORMATTERS & LINTERS
-- ============================================================

-- Formatting: conform.nvim (deterministic external formatters)
local conform = require("conform")

-- ------------------------------------------------------------
-- Format-on-save policy
-- ------------------------------------------------------------
-- Manual formatting (<leader>f) always works, with the tool the project uses.
-- Saving only formats when the project configures the formatter that would
-- run, so opening someone else's repository never restyles their files.
-- Each entry says what counts as "configured":
--   "conform"  conform's own root files for that formatter
--   list       any of these files above the buffer
--   function   custom check, given the buffer's directory
-- A formatter with no entry (dockerfmt) is manual-only.

---@param dir string
---@param names string[]
---@return string?
local function find_up(dir, names)
	return vim.fs.find(names, { path = dir, upward = true, type = "file" })[1]
end

-- Ruff: a pyproject.toml alone doesn't mean Ruff is the project's formatter
-- (it may use Black), so require a [tool.ruff] table or a ruff.toml.
---@param dir string
local function has_ruff_config(dir)
	if find_up(dir, { "ruff.toml", ".ruff.toml" }) then
		return true
	end
	local pyprojects = vim.fs.find("pyproject.toml", { path = dir, upward = true, type = "file", limit = math.huge })
	for _, file in ipairs(pyprojects) do
		for line in io.lines(file) do
			if line:match("^%s*%[tool%.ruff[%.%]]") then
				return true
			end
		end
	end
	return false
end

local project_markers = {
	biome = "conform", -- biome.json / biome.jsonc
	prettier = "conform", -- .prettierrc*, prettier.config.*, or a "prettier" key in package.json
	stylua = "conform", -- stylua.toml / .stylua.toml
	["clang-format"] = { ".clang-format", "_clang-format" },
	ruff_format = has_ruff_config,
	taplo = { "taplo.toml", ".taplo.toml" },
	shfmt = { ".editorconfig" },
	-- One canonical style and no (or rarely any) config file: the project
	-- manifest is the marker.
	rustfmt = { "Cargo.toml", "rustfmt.toml", ".rustfmt.toml" },
	goimports = { "go.mod", "go.work" },
}

---@param name string formatter name
---@param bufnr integer
---@return boolean
local function project_configures(name, bufnr)
	local file = vim.api.nvim_buf_get_name(bufnr)
	local marker = project_markers[name]
	if file == "" or not marker then
		return false
	end
	if marker == "conform" then
		return conform.get_formatter_info(name, bufnr).cwd ~= nil
	end
	local dir = vim.fs.dirname(file)
	if type(marker) == "function" then
		return marker(dir)
	end
	---@cast marker string[]
	return find_up(dir, marker) ~= nil
end

-- JS/TS/JSON: use whichever of Biome or Prettier the project configures.
-- With neither, Biome is the manual-format default.
---@param bufnr integer
local function biome_or_prettier(bufnr)
	if project_configures("biome", bufnr) then
		return { "biome" }
	end
	if project_configures("prettier", bufnr) then
		return { "prettier" }
	end
	return { "biome" }
end

conform.setup({
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "ruff_format" },

		javascript = biome_or_prettier,
		javascriptreact = biome_or_prettier,
		typescript = biome_or_prettier,
		typescriptreact = biome_or_prettier,

		c = { "clang-format" },
		cpp = { "clang-format" },

		rust = { "rustfmt" },
		go = { "goimports" },

		sh = { "shfmt" },

		markdown = { "prettier" },
		yaml = { "prettier" },

		toml = { "taplo" },

		json = biome_or_prettier,
		jsonc = biome_or_prettier,

		dockerfile = { "dockerfmt" },
		-- yaml.ansible needs no entry: conform falls back to "yaml" (prettier),
		-- and Prettier infers YAML from the filename. Lint fixes need :AnsibleFix.
	},

	-- Format on save: honours the global and buffer toggles, then the policy above.
	format_on_save = function(bufnr)
		if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
			return
		end

		local formatters = {}
		-- Prettier's startup can exceed 500 ms; keep other saves responsive.
		local timeout_ms = 500
		for _, formatter in ipairs(conform.list_formatters_to_run(bufnr)) do
			if project_configures(formatter.name, bufnr) then
				formatters[#formatters + 1] = formatter.name
				if formatter.name == "prettier" then
					timeout_ms = 2000
				end
			end
		end
		if #formatters == 0 then
			return
		end
		-- No LSP fallback here: a language server has no notion of "the
		-- project configures this", so LSP formatting stays manual.
		return { timeout_ms = timeout_ms, formatters = formatters, lsp_format = "never" }
	end,
})

-- Manual format trigger
vim.keymap.set("n", "<leader>f", function()
	conform.format({ async = true, lsp_format = "fallback" })
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

	conform.format({
		bufnr = bufnr,
		formatters = { "ansible-lint" },
		async = true,
		lsp_format = "never",
	})
end, { desc = "Apply Ansible lint fixes to buffer (review before saving)" })

-- Toggle format-on-save: <leader>tf for this buffer, <leader>tF everywhere.
-- The statusline shows a marker while either is off (ui.lua).
vim.keymap.set("n", "<leader>tf", function()
	vim.b.disable_autoformat = not vim.b.disable_autoformat
	vim.notify("Format on save (buffer): " .. (vim.b.disable_autoformat and "off" or "on"))
	vim.cmd.redrawstatus()
end, { desc = "[T]oggle [F]ormat on save (buffer)" })
vim.keymap.set("n", "<leader>tF", function()
	vim.g.disable_autoformat = not vim.g.disable_autoformat
	vim.notify("Format on save (global): " .. (vim.g.disable_autoformat and "off" or "on"))
	vim.cmd.redrawstatus({ bang = true })
end, { desc = "[T]oggle [F]ormat on save (global)" })

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
