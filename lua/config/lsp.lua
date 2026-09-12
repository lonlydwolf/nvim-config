-- ============================================================
-- LSP SETUP
-- ============================================================

-- nvim-lspconfig ships server definitions under lsp/*.lua.
-- We use vim.lsp.enable() (Neovim 0.11+) instead of manual setup calls.

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

	-- C / C++
	"clangd",

	-- Rust
	"rust_analyzer",

	-- Go
	"gopls",

	-- Bash / Zsh
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

-- 1. Lua: Expose Neovim runtime library for auto-completion & docs on vim.*
vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				checkThirdParty = false,
				library = { vim.env.VIMRUNTIME },
			},
		},
	},
})

-- 2. Bash: Enable on zsh files (.zshrc, scripts)
vim.lsp.config("bashls", {
	filetypes = { "bash", "sh", "zsh" },
})

-- 3. Ansible: Add .git as fallback root so playbooks start without ansible.cfg
vim.lsp.config("ansiblels", {
	root_markers = { "ansible.cfg", ".ansible-lint", ".git" },
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

-- 5. Go (gopls): Enable inlay hints (opt-in)
vim.lsp.config("gopls", {
	settings = {
		gopls = {
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

-- 6. JSON & YAML: Schemastore integration
vim.lsp.config("jsonls", {
	settings = {
		json = {
			schemas = require("schemastore").json.schemas(),
			validate = { enable = true },
		},
	},
})

vim.lsp.config("yamlls", {
	settings = {
		yaml = {
			schemaStore = { enable = false, url = "" },
			schemas = require("schemastore").yaml.schemas(),
		},
	},
})

-- ============================================================
-- DIAGNOSTICS CONFIGURATION
-- ============================================================

vim.diagnostic.config({
	virtual_text = false,
	virtual_lines = { current_line = true },
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
		local opts = { buffer = ev.buf }
		local client = vim.lsp.get_client_by_id(ev.data.client_id)

		-- --------------------------------------------------------
		-- Navigation
		-- --------------------------------------------------------

		vim.keymap.set(
			"n",
			"gd",
			vim.lsp.buf.definition,
			vim.tbl_extend("force", opts, { desc = "[G]o to [D]efinition" })
		)

		vim.keymap.set(
			"n",
			"gD",
			vim.lsp.buf.declaration,
			vim.tbl_extend("force", opts, { desc = "[G]o to [D]eclaration" })
		)

		-- --------------------------------------------------------
		-- Diagnostics → Quickfix
		-- --------------------------------------------------------

		vim.keymap.set("n", "<leader>ld", function()
			vim.diagnostic.setqflist({ bufnr = 0 })
		end, vim.tbl_extend("force", opts, { desc = "[L]SP [D]iagnostics → quickfix" }))

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
				buffer = ev.buf,
				callback = vim.lsp.buf.document_highlight,
			})

			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				group = group,
				buffer = ev.buf,
				callback = vim.lsp.buf.clear_references,
			})

			vim.api.nvim_create_autocmd("LspDetach", {
				group = vim.api.nvim_create_augroup("user-lsp-detach-" .. ev.buf, { clear = true }),
				buffer = ev.buf,
				callback = function(detach_ev)
					vim.lsp.buf.clear_references()
					vim.api.nvim_clear_autocmds({
						group = "user-lsp-highlight-" .. detach_ev.buf,
						buffer = detach_ev.buf,
					})
				end,
			})
		end
	end,
})
