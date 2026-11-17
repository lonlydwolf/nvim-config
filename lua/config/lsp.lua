-- ============================================================
-- LSP SETUP
-- ============================================================

-- nvim-lspconfig ships server definitions under lsp/*.lua.
-- We use vim.lsp.enable() instead of manual setup calls. Requires Neovim 0.12+ (vim.pack).

-- ============================================================
-- ENABLE LSP SERVERS
-- ============================================================

local servers = {
	-- Lua
	"lua_ls",

	-- Python
	"basedpyright",
	"ruff",

	-- JavaScript / TypeScript
	"vtsls",
	"biome", -- lint diagnostics + quick fixes; only attaches where a Biome config exists
	"eslint", -- same for ESLint projects; only attaches where an ESLint config exists

	-- C / C++
	"clangd",

	-- Rust
	"rust_analyzer",

	-- Go
	"gopls",

	-- Bash / sh (not zsh: ShellCheck doesn't support it)
	"bashls",

	-- Ansible
	"ansiblels",

	-- Markdown
	"marksman",

	-- YAML
	"yamlls",

	-- JSON
	"jsonls",

	-- TOML
	"taplo",

	-- Dockerfile / Compose (official docker-language-server)
	"docker_language_server",
}

vim.lsp.enable(servers)

-- ============================================================
-- SERVER-SPECIFIC CONFIGURATION
-- ============================================================

-- 1. Lua: LuaJIT and the Neovim runtime library (completion and docs on vim.*),
-- but only where the Lua being edited is Neovim Lua: this config, installed
-- plugins and the runtime itself. Any other Lua project keeps lua_ls defaults
-- and its own .luarc.json, instead of being told `vim` exists.
local function is_nvim_lua(root)
	root = vim.uv.fs_realpath(root) or root
	for _, dir in ipairs({ vim.fn.stdpath("config"), vim.fn.stdpath("data"), vim.env.VIMRUNTIME }) do
		dir = vim.uv.fs_realpath(dir) or dir
		if root == dir or vim.startswith(root, dir .. "/") then
			return true
		end
	end
	return false
end

vim.lsp.config("lua_ls", {
	on_init = function(client)
		local folder = client.workspace_folders and client.workspace_folders[1]
		if not (folder and is_nvim_lua(folder.name)) then
			return
		end
		client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
			runtime = {
				version = "LuaJIT",
				path = { "lua/?.lua", "lua/?/init.lua" },
			},
			workspace = {
				checkThirdParty = false,
				library = { vim.env.VIMRUNTIME },
			},
		})
	end,
	settings = {
		Lua = {},
	},
})

-- 2. Ansible: Add .git as fallback root + ansible-lint diagnostics
vim.lsp.config("ansiblels", {
	root_markers = { "ansible.cfg", ".ansible-lint", ".git" },
	settings = {
		ansible = {
			validation = {
				lint = {
					enabled = true,
					path = "ansible-lint",
				},
			},
		},
	},
})

-- 3. Rust (rust-analyzer): Clippy diagnostics on check
vim.lsp.config("rust_analyzer", {
	settings = {
		["rust-analyzer"] = {
			check = {
				command = "clippy",
			},
		},
	},
})

-- 4. TypeScript / JavaScript (vtsls): Enable inlay hints (opt-in)
vim.lsp.config("vtsls", {
	settings = {
		typescript = {
			inlayHints = {
				parameterNames = { enabled = "all" },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = true },
				propertyDeclarationTypes = { enabled = true },
				functionLikeReturnTypes = { enabled = true },
				enumMemberValues = { enabled = true },
			},
		},
		javascript = {
			inlayHints = {
				parameterNames = { enabled = "all" },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = true },
				propertyDeclarationTypes = { enabled = true },
				functionLikeReturnTypes = { enabled = true },
				enumMemberValues = { enabled = true },
			},
		},
	},
})

-- 5. Go (gopls): Enable inlay hints (opt-in) + staticcheck
vim.lsp.config("gopls", {
	settings = {
		gopls = {
			staticcheck = true,
			hints = {
				assignVariableTypes = true,
				compositeLiteralFields = true,
				compositeLiteralTypes = true,
				constantValues = true,
				functionTypeParameters = true,
				parameterNames = true,
				rangeVariableTypes = true,
			},
		},
	},
})

-- 6. JSON & YAML: Schemastore integration. The catalogs are several thousand
-- lines, so they are attached when a server starts (before_init) rather than
-- stored in the static config, where they made `:checkhealth vim.lsp`
-- unreadable and were built at every startup.
vim.lsp.config("jsonls", {
	before_init = function(_, config)
		config.settings.json.schemas = require("schemastore").json.schemas()
	end,
	settings = {
		json = {
			validate = { enable = true },
		},
	},
})

vim.lsp.config("yamlls", {
	before_init = function(_, config)
		config.settings.yaml.schemas = require("schemastore").yaml.schemas()
	end,
	settings = {
		yaml = {
			schemaStore = { enable = false, url = "" },
		},
	},
})

-- 7. Python: one owner per finding. Ruff and basedpyright both report unused
-- imports, unused variables and undefined names, so each showed up twice.
--   Ruff         unused imports (F401) and variables (F841): it has the fixes.
--   basedpyright undefined names: it is type-aware and stays on even when a
--                project's Ruff config does not select the F rules.
-- Project config still wins: pyrightconfig.json / [tool.basedpyright] override
-- these severities, and the Ruff ignore is added to the project's own.
--
-- basedpyright runs in its default "recommended" mode. For fewer type warnings
-- set `vim.g.basedpyright_type_checking_mode = "standard"` (here, or in a
-- project's .nvim.lua), or typeCheckingMode in the project's own config.
vim.lsp.config("basedpyright", {
	before_init = function(_, config)
		-- Read at server start, so a project-local .nvim.lua can set it.
		local mode = vim.g.basedpyright_type_checking_mode
		if mode then
			config.settings.basedpyright.analysis.typeCheckingMode = mode
		end
	end,
	settings = {
		basedpyright = {
			disableOrganizeImports = true, -- Ruff's "organize imports" code action owns this
			analysis = {
				diagnosticSeverityOverrides = {
					reportUnusedImport = "none",
					reportUnusedVariable = "none",
				},
			},
		},
	},
})

vim.lsp.config("ruff", {
	init_options = {
		settings = {
			lint = { ignore = { "F821" } },
		},
	},
})

-- ============================================================
-- DIAGNOSTICS CONFIGURATION
-- ============================================================

-- Both only on the cursor line. Errors expand below it with the full message;
-- warnings and hints stay at the end of the line, so moving over them no
-- longer shifts the code up and down. <C-w>d opens the full float.
local severity = vim.diagnostic.severity
vim.diagnostic.config({
	virtual_lines = { current_line = true, severity = severity.ERROR },
	virtual_text = { current_line = true, severity = { max = severity.WARN }, source = "if_many" },
	float = { source = true },
	signs = true,
	underline = true,
	severity_sort = true,
})

-- ============================================================
-- LSP ATTACH BEHAVIOR (keymaps + features)
-- ============================================================

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),

	callback = function(ev)
		local opts = { buf = ev.buf }
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		local fzf = require("fzf-lua")

		-- --------------------------------------------------------
		-- Navigation (fzf-lua)
		-- --------------------------------------------------------

		vim.keymap.set("n", "gd", fzf.lsp_definitions, vim.tbl_extend("force", opts, { desc = "[G]o to [D]efinition" }))

		vim.keymap.set(
			"n",
			"gD",
			fzf.lsp_declarations,
			vim.tbl_extend("force", opts, { desc = "[G]o to [D]eclaration" })
		)

		vim.keymap.set("n", "grr", fzf.lsp_references, vim.tbl_extend("force", opts, { desc = "[G]o to [R]eferences" }))

		vim.keymap.set(
			"n",
			"gri",
			fzf.lsp_implementations,
			vim.tbl_extend("force", opts, { desc = "[G]o to [I]mplementation" })
		)

		-- grt is the built-in key for type definition (same family as grr/gri).
		vim.keymap.set(
			"n",
			"grt",
			fzf.lsp_typedefs,
			vim.tbl_extend("force", opts, { desc = "[G]o to [T]ype Definition" })
		)

		vim.keymap.set(
			"n",
			"gO",
			fzf.lsp_document_symbols,
			vim.tbl_extend("force", opts, { desc = "Document [O]utline (Symbols)" })
		)

		-- Diagnostics pickers live on <leader>sd / <leader>sD (finder.lua): they
		-- also list nvim-lint results, so they must not depend on an LSP attach.

		-- --------------------------------------------------------
		-- LSP Restart
		-- --------------------------------------------------------

		vim.keymap.set(
			"n",
			"<leader>lr",
			"<cmd>lsp restart<CR>",
			vim.tbl_extend("force", opts, { desc = "[L]SP [R]estart client" })
		)

		-- --------------------------------------------------------
		-- Inlay hints (buffer toggle)
		-- --------------------------------------------------------

		if client and client:supports_method("textDocument/inlayHint") then
			vim.keymap.set("n", "<leader>th", function()
				local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
				vim.lsp.inlay_hint.enable(not enabled, { bufnr = ev.buf })
			end, vim.tbl_extend("force", opts, { desc = "[T]oggle [H]ints inlay" }))
		end

		-- --------------------------------------------------------
		-- Document highlight
		-- --------------------------------------------------------

		if client and client:supports_method("textDocument/documentHighlight") then
			local group = vim.api.nvim_create_augroup("user-lsp-highlight-" .. ev.buf, { clear = true })

			vim.api.nvim_create_autocmd("CursorHold", {
				group = group,
				buf = ev.buf,
				callback = vim.lsp.buf.document_highlight,
			})

			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				group = group,
				buf = ev.buf,
				callback = vim.lsp.buf.clear_references,
			})

			vim.api.nvim_create_autocmd("LspDetach", {
				group = vim.api.nvim_create_augroup("user-lsp-detach-" .. ev.buf, { clear = true }),
				buf = ev.buf,
				callback = function(detach_ev)
					local departing_id = detach_ev.data and detach_ev.data.client_id
					local remaining_has_highlight = vim.iter(vim.lsp.get_clients({ bufnr = detach_ev.buf }))
						:any(function(c)
							return c.id ~= departing_id and c:supports_method("textDocument/documentHighlight")
						end)

					if not remaining_has_highlight then
						if vim.api.nvim_buf_is_valid(detach_ev.buf) then
							vim.api.nvim_buf_call(detach_ev.buf, vim.lsp.buf.clear_references)
						end
						vim.api.nvim_clear_autocmds({
							group = "user-lsp-highlight-" .. detach_ev.buf,
							buf = detach_ev.buf,
						})
					end
				end,
			})
		end
	end,
})
